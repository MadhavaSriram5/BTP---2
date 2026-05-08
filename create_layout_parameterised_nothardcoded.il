;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;; Helper: Snap to 5nm grid ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(customSnap(val)
  if(numberp(val) then round(val / 0.005) * 0.005 else val)
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper: get viaDef
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(getViaDefByName(cv viaName)
  let((tf viaDef) tf = techGetTechFile(cv) techFindViaDefByName(tf viaName))
)

procedure(placeM2toM7Via(cv x y)
  let( (viaNames)
    viaNames = list(
      "M3_M2"
      "M4_M3"
      "M5_M4"
      "M6_M5"
      "M7_M6"
    )

    foreach(vn viaNames
      dbCreateVia(
  cv
  getViaDefByName(cv vn)
  list(x y)
  "R0"
  list(
    list("cutRows" 4)
    list("cutColumns" 1)
    list("cutSpacing" list(0.14 0.14))
  )
)

    )
  )
)

procedure(placeM7toM8Via(cv x y)
  let( (viaNames)
    viaNames = list(
      "M8_M7"
    )

    foreach(vn viaNames
      dbCreateVia(
        cv
	getViaDefByName(cv vn)
        list(x y)
        "R0"
      )
    )
  )
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROCEDURE: placeViaStack
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;procedure(placeViaStack(cv pt startLayer endLayer)
;;    let((allLayers sList eList sIdx eIdx viaName vDef dir)
;;        allLayers = list("M1" "M2" "M3" "M4" "M5" "M6" "M7" "M8" "M9" "AP")
;;        sList = member(startLayer allLayers) eList = member(endLayer allLayers)
;;        if(sList && eList then
;;            sIdx = length(allLayers) - length(sList)
;;            eIdx = length(allLayers) - length(eList)
;;            if(sIdx != eIdx then
;;                dir = if(sIdx < eIdx 1 -1)
;;                for(i 0 abs(sIdx - eIdx)-1
;;                    let((curr next vName)
;;                        curr = nthelem(sIdx + (i * dir) + 1 allLayers)
;;                        next = nthelem(sIdx + ((i+1) * dir) + 1 allLayers)
;;                        vName = if(sIdx + (i * dir) < sIdx + ((i+1) * dir)
;;                                   sprintf(nil "%s_%s" next curr)
;;                                   sprintf(nil "%s_%s" curr next))
;;                        vDef = getViaDefByName(cv vName)
;;                        if(vDef then dbCreateVia(cv vDef pt "R0"))
;;                    )
;;                )
    ;;        )
  ;;	  )
;;    )
;;)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROCEDURE: placeViaStack
;; Forces both bottom and top metal patches to via footprint
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(placeViaStack(cv pt startLayer endLayer)
    let((allLayers sList eList sIdx eIdx viaName vDef dir)
        allLayers = list("M1" "M2" "M3" "M4" "M5" "M6" "M7" "M8" "M9" "AP")
        sList = member(startLayer allLayers) eList = member(endLayer allLayers)

        if(sList && eList then
            sIdx = length(allLayers) - length(sList)
            eIdx = length(allLayers) - length(eList)

            if(sIdx != eIdx then
                dir = if(sIdx < eIdx 1 -1)
                for(i 0 abs(sIdx - eIdx)-1
                    let((curr next vName vDef vInst vBox)
                        ;; Identify the two layers for this specific via in the stack
                        curr = nthelem(sIdx + (i * dir) + 1 allLayers)
                        next = nthelem(sIdx + ((i+1) * dir) + 1 allLayers)

                        ;; Determine via name (e.g., "M2_M1" or "M1_M2")
                        vName = if(sIdx + (i * dir) < sIdx + ((i+1) * dir)
                                   sprintf(nil "%s_%s" next curr)
                                   sprintf(nil "%s_%s" curr next))

                        vDef = getViaDefByName(cv vName)
                        if(vDef then
                            ;; Create the via instance
                            vInst = dbCreateVia(cv vDef pt "R0")

                            ;; If the via exists, grab its bBox to draw the patches
                            if(vInst && vInst~>bBox then
                                vBox = vInst~>bBox

                                ;; DRAW BOTH LAYERS (mx and my)
                                ;; This ensures the landing pad and the take-off pad
                                ;; are perfectly rectangular and match the via exactly.
                                dbCreateRect(cv list(curr "drawing") vBox)
                                dbCreateRect(cv list(next "drawing") vBox)
                            )
                        )
                    )
                )
            )
	)
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROCEDURE: getAllLayerBBoxes
;; Gather obstacle bboxes on a given layer: top-level shapes drawn so
;; far + pin figures of instances. Used by the short-detection pass in
;; placeRobustRoute.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(getAllLayerBBoxes(cv layer)
    let((bboxes)
        bboxes = nil
        foreach(s cv~>shapes
            when(s~>layerName == layer && s~>bBox
                bboxes = cons(s~>bBox bboxes)
            )
        )
        foreach(inst cv~>instances
            when(inst~>master
                foreach(term inst~>master~>terminals
                    foreach(pin term~>pins
                        foreach(fig pin~>figs
                            when(fig~>layerName == layer && fig~>bBox
                                bboxes = cons(dbTransformBBox(fig~>bBox inst~>transform) bboxes)
                            )
                        )
                    )
                )
            )
        )
        bboxes
    )
)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROCEDURE: segmentCrossesAnyBBox
;; Axis-aligned segment vs. bbox list. Returns t if the segment passes
;; THROUGH any bbox. A segment whose endpoint lies inside a bbox is
;; treated as an intentional pin entry/exit and is NOT flagged.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(segmentCrossesAnyBBox(p1 p2 bboxes)
    let((x1 y1 x2 y2 result)
        result = nil
        x1 = xCoord(p1) y1 = yCoord(p1)
        x2 = xCoord(p2) y2 = yCoord(p2)
        foreach(bb bboxes
            unless(result
                let((xmin ymin xmax ymax)
                    xmin = xCoord(lowerLeft(bb))  ymin = yCoord(lowerLeft(bb))
                    xmax = xCoord(upperRight(bb)) ymax = yCoord(upperRight(bb))
                    cond(
                        ;; Horizontal segment (constant y)
                        ((y1 == y2)
                            when(y1 > ymin && y1 < ymax
                                let((segMin segMax p1In p2In)
                                    segMin = min(x1 x2) segMax = max(x1 x2)
                                    p1In = (x1 >= xmin && x1 <= xmax)
                                    p2In = (x2 >= xmin && x2 <= xmax)
                                    when(segMin < xmax && segMax > xmin && !p1In && !p2In
                                        result = t
                                    )
                                )
                            )
                        )
                        ;; Vertical segment (constant x)
                        ((x1 == x2)
                            when(x1 > xmin && x1 < xmax
                                let((segMin segMax p1In p2In)
                                    segMin = min(y1 y2) segMax = max(y1 y2)
                                    p1In = (y1 >= ymin && y1 <= ymax)
                                    p2In = (y2 >= ymin && y2 <= ymax)
                                    when(segMin < ymax && segMax > ymin && !p1In && !p2In
                                        result = t
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
        result
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROCEDURE: getEscapeLayer
;; Return the next-higher metal for obstacle bypassing. If already at
;; the top, return the same layer (caller skips elevation).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(getEscapeLayer(layer)
    let((allLayers lst)
        allLayers = list("M1" "M2" "M3" "M4" "M5" "M6" "M7" "M8" "M9" "AP")
        lst = member(layer allLayers)
        if(lst && cdr(lst) then cadr(lst) else layer)
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROCEDURE: getExtrudedPin
;; Supports explicit directions: "down", "up", "left", "right"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(getExtrudedPin(cv inst pinName @optional (dir "auto") (extDist 2.0))
    let((master targetTerm allFigs metalFig l_bBox px py ox oy ex ey layer)
        master = inst~>master
        targetTerm = car(exists(term master~>terminals upperCase(term~>name) == upperCase(pinName)))
        if(targetTerm then
            allFigs = list()
            foreach(pin targetTerm~>pins foreach(fig pin~>figs allFigs = cons(fig allFigs)))
            metalFig = car(exists(f allFigs f~>layerPurpose == "drawing")) || car(allFigs)

            if(metalFig && metalFig~>bBox then
                layer = metalFig~>layerName
                l_bBox = dbTransformBBox(metalFig~>bBox inst~>transform)
                px = customSnap((xCoord(lowerLeft(l_bBox)) + xCoord(upperRight(l_bBox)))/2.0)
                py = customSnap((yCoord(lowerLeft(l_bBox)) + yCoord(upperRight(l_bBox)))/2.0)
                ox = xCoord(inst~>xy) oy = yCoord(inst~>xy)

                cond(
                    (dir == "down"  ex = px ey = py - extDist)
                    (dir == "up"    ex = px ey = py + extDist)
                    (dir == "left"  ex = px - extDist ey = py)
                    (dir == "right" ex = px + extDist ey = py)
                    (t
                        if(abs(px - ox) > abs(py - oy) then
                            ex = if(px >= ox px + extDist px - extDist) ey = py
                        else
                            ey = if(py >= oy py + extDist py - extDist) ex = px
                        )
                    )
                )
                ex = customSnap(ex) ey = customSnap(ey)
                dbCreatePath(cv list(layer "drawing") list(list(px py) list(ex ey)) 0.09)
                list(list(ex ey) layer)
            else nil)
        else nil)
    )
)

procedure(getExtrudedPinforCap(cv inst pinName @optional (dir "auto") (extDist 2.0))
    let((master targetTerm allFigs metalFig l_bBox px py ox oy ex ey layer)
        master = inst~>master
        targetTerm = car(exists(term master~>terminals upperCase(term~>name) == upperCase(pinName)))
        if(targetTerm then
            allFigs = list()
            foreach(pin targetTerm~>pins foreach(fig pin~>figs allFigs = cons(fig allFigs)))
            metalFig = car(exists(f allFigs f~>layerPurpose == "drawing")) || car(allFigs)

            if(metalFig && metalFig~>bBox then
                layer = metalFig~>layerName
                l_bBox = dbTransformBBox(metalFig~>bBox inst~>transform)
                px = customSnap((xCoord(lowerLeft(l_bBox)) + xCoord(upperRight(l_bBox)))/2.0)
                py = customSnap((yCoord(lowerLeft(l_bBox)) + yCoord(upperRight(l_bBox)))/2.0)
                ox = xCoord(inst~>xy) oy = yCoord(inst~>xy)

                cond(
                    (dir == "down"  ex = px ey = py - extDist)
                    (dir == "up"    ex = px ey = py + extDist)
                    (dir == "left"  ex = px - extDist ey = py)
                    (dir == "right" ex = px + extDist ey = py)
                    (t
                      	if(abs(px - ox) > abs(py - oy) then
                            ex = if(px >= ox px + extDist px - extDist) ey = py
                        else
                            ey = if(py >= oy py + extDist py - extDist) ex = px
                        )
                    )
                )
                ex = customSnap(ex) ey = customSnap(ey)
                dbCreatePath(cv list(layer "drawing") list(list(px py) list(ex ey)) 0.85)
                list(list(ex ey) layer)
            else nil)
        else nil)
    )
)

procedure(placeRobustRoute(cv pinData1 pinData2)
    when(pinData1 && pinData2
        let((pt1 layer1 pt2 layer2 elbowPt routeLayer bboxes needsEsc escLayer allLayers sIdx eIdx)
            allLayers = list("M1" "M2" "M3" "M4" "M5" "M6" "M7" "M8" "M9" "AP")
            pt1 = car(pinData1)  layer1 = cadr(pinData1)
            pt2 = car(pinData2)  layer2 = cadr(pinData2)

            routeLayer = layer2
            elbowPt    = list(xCoord(pt2) yCoord(pt1))   ;; <-- renamed

            bboxes   = getAllLayerBBoxes(cv routeLayer)
            ;; Keep || on ONE line to avoid SKILL statement-splitting
            needsEsc = segmentCrossesAnyBBox(pt1 elbowPt bboxes) || segmentCrossesAnyBBox(elbowPt pt2 bboxes)

            if(needsEsc then
                escLayer = getEscapeLayer(routeLayer)
                if(escLayer != routeLayer then
                    printf("\n[placeRobustRoute] Short on %s; elevating to %s.\n" routeLayer escLayer)
                    routeLayer = escLayer
                )
            )

            ;; --- ADJACENCY LOGIC FOR POINT 1 ---
            sIdx = length(allLayers) - length(member(layer1     allLayers))
            eIdx = length(allLayers) - length(member(routeLayer allLayers))
            cond(
                (layer1 == routeLayer     nil)
                (abs(sIdx - eIdx) == 1    placeViaStack(cv pt1 layer1 routeLayer))
                (t                        placeM2toM7Via(cv xCoord(pt1) yCoord(pt1)))
            )

            ;; --- ADJACENCY LOGIC FOR POINT 2 ---
            sIdx = length(allLayers) - length(member(layer2     allLayers))
            eIdx = length(allLayers) - length(member(routeLayer allLayers))
            cond(
                (layer2 == routeLayer     nil)
                (abs(sIdx - eIdx) == 1    placeViaStack(cv pt2 layer2 routeLayer))
                (t                        placeM2toM7Via(cv xCoord(pt2) yCoord(pt2)))
            )

            ;; Draw the L-route on the chosen layer
            dbCreatePath(cv list(routeLayer "drawing") list(pt1 elbowPt pt2) 0.18)
        )
    )
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROCEDURE: createFinalPort
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(createFinalPort(cv netName pinData)
    when(pinData
        let((pt layer net rect term)
            pt = car(pinData) layer = cadr(pinData)
            net = dbFindNetByName(cv netName) || dbCreateNet(cv netName)
            rect = dbCreateRect(cv list(layer "pin")
                    list(list(xCoord(pt)-0.1 yCoord(pt)-0.1) list(xCoord(pt)+0.1 yCoord(pt)+0.1)))
            term = dbCreateTerm(net netName "inputOutput")
            dbCreatePin(net rect netName term)
            dbCreateLabel(cv list(layer "pin") pt netName "centerCenter" "R0" "stick" 0.1)
        )
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROCEDURE: getPinCenterAndLayer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(getPinCenterAndLayer(cv inst pinName)
    let((master targetTerm allFigs metalFig l_bBox center)
        master = inst~>master
        targetTerm = car(exists(term master~>terminals upperCase(term~>name) == upperCase(pinName)))
        if(targetTerm then
            allFigs = list()
            foreach(pin targetTerm~>pins foreach(fig pin~>figs allFigs = cons(fig allFigs)))
            metalFig = car(exists(f allFigs f~>layerPurpose == "drawing")) || car(allFigs)
            if(metalFig && metalFig~>bBox then
                l_bBox = dbTransformBBox(metalFig~>bBox inst~>transform)
                center = list(customSnap((xCoord(lowerLeft(l_bBox)) + xCoord(upperRight(l_bBox)))/2.0)
                              customSnap((yCoord(lowerLeft(l_bBox)) + yCoord(upperRight(l_bBox)))/2.0))
                list(center metalFig~>layerName)
            else nil)
        else nil)
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MAIN FLOW
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
procedure(runPortCheck(viewName)
  let((cv m0 m1 c0 g0_raw d0_raw g1_raw d1_raw s0 d0 b0 s1 d1 b1 cPlus cMinus cBulk params capParams)
    cv = dbOpenCellViewByType("trying_tsmc" viewName "layout" "maskLayout" "w")
    if(cv then
        params = list(list("w" "string" "2u") list("fingers" "string" "2") list("l" "string" "200n")
                      list("bodytie_typeR" "string" "Detached") list("swDmyPoly" "boolean" t)
                      list("TFdrn" "boolean" t) list("HardCons" "boolean" t)
                      list("routePolydir" "string" "Top") list("polyContacts" "boolean" t)
                      list("routeSD" "string" "Both") list("LargeDrain" "boolean" t))
        capParams = list(list("select_CAP" "string" "MIM_2.0F") list("Entry_mode" "string" "L&W")
                         list("lt" "string" "15u") list("wt" "string" "10u")
                         list("SubstrateType" "string" "NW") list("Adding_DMEXCL_Layer" "boolean" t)
                         list("Hard_constrain" "boolean" t))

        m0 = dbCreateParamInstByMasterName(cv "tsmcN65" "nch_na" "layout" "MN0" list(0 0)    "R0" 1 params)
        m1 = dbCreateParamInstByMasterName(cv "tsmcN65" "nch_na" "layout" "MN1" list(15 0)   "MY" 1 params)
        c0 = dbCreateParamInstByMasterName(cv "tsmcN65" "mimcap_woum_rf" "layout" "C0" list(8.5 15) "R0" 1 capParams)

        ;; 1. DIODE CONNECTIONS (Direct to original internal pins, NO EXTRUSION)
        g0_raw = car(getPinCenterAndLayer(cv m0 "G")) d0_raw = car(getPinCenterAndLayer(cv m0 "D"))
        g1_raw = car(getPinCenterAndLayer(cv m1 "G")) d1_raw = car(getPinCenterAndLayer(cv m1 "D"))

        when(g0_raw && d0_raw dbCreatePath(cv list("M1" "drawing") list(g0_raw list(xCoord(d0_raw) yCoord(g0_raw)) d0_raw) 0.09))
        when(g1_raw && d1_raw dbCreatePath(cv list("M1" "drawing") list(g1_raw list(xCoord(d1_raw) yCoord(g1_raw)) d1_raw) 0.09))

        ;; 2. EXTRUDE PINS WITH VARIED LENGTHS (Staggered Tracks for Nets)
        s0 = getExtrudedPin(cv m0 "S" "down" 2.5)
        s1 = getExtrudedPin(cv m1 "S" "down" 3.5)

        d0 = getExtrudedPin(cv m0 "D" "up" 3.0)
        d1 = getExtrudedPin(cv m1 "D" "up" 4.5)

        b0 = getExtrudedPin(cv m0 "B" "down" 2.0)
        b1 = getExtrudedPin(cv m1 "B" "down" 2.0)

        cPlus  = getExtrudedPinforCap(cv c0 "PLUS"  "left"  2.5)
        cMinus = getExtrudedPinforCap(cv c0 "MINUS" "right" 4.0)
        cBulk  = getExtrudedPin(cv c0 "BULK"  "right" 3.5)

        ;;        dbCreatePath(cv list("M8" "drawing") list(list(car(cMinus)-1.6 cadr(cMinus)) list(car(cMinus)+1.6 cadr(cMinus))) 0.4)
        dbCreatePath(cv list("M8" "drawing") list(list(caar(cMinus) - 1.6 cadar(cMinus)) list(caar(cMinus) + 1.6 cadar(cMinus))) 0.85)

        ;; 3. NETLIST ROUTING (now obstacle-aware: auto-elevates if a same-layer short is detected)
        placeRobustRoute(cv b0 b1)        ;; m1b to m2b
        placeRobustRoute(cv d0 b0)        ;; m1d to m1b
        placeRobustRoute(cv s0 d1)        ;; m1s to m2d
        placeRobustRoute(cv cMinus d1)    ;; cap -ve to m2d (this one elevates to M2 to clear cBulk)

        ;; 4. PORT PLACEMENT
        createFinalPort(cv "cell_in"  cPlus)
        createFinalPort(cv "vdd"      cBulk)
        createFinalPort(cv "gnd"      b1)
        createFinalPort(cv "cell_out" s1)

        dbSave(cv) dbClose(cv)
        printf("\nIntegrated Layout Finished with Obstacle-Aware Routing.\n")
    )
  )
)

runPortCheck("mos_cap_test_trying_via")
exit()

