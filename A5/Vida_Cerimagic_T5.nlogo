;-------------------------------HEADER---------------------------
extensions [palette array]
breed [processors processor]
breed [gps gp]

processors-own[material pheromone concentrations]
gps-own[gp_type gp_pos visited concentrations concentration]
globals[mouse-was-down? growing-point initial-GP-set static-GP-set gp-counter rad act_gp act_gp_type done manual-version active-gp-list hc-counter hc_minus]



;-------------------------------SETUP----------------------------

to setup
  ; Clear patches and turtles
  ca

  ; Create background and processors
  ask patches
  [
    set pcolor black
  ]
  ask n-of number-processors patches [
    sprout-processors 1 [
      set size 0.5
      set color grey
      set shape "circle"
      set label ""
    ]
  ]

  ; Shuffle processors a little bit to create a non-regular pattern
  shuffle-processors

  ask processors [
    set concentrations array:from-list n-values max_number_of_gps [0]
  ]

  set gp-counter 0
  set hc-counter 0
  set rad 1
  set act_gp 0
  set done false

  ; Ask user to place the moving GP
  ;user-message "To begin, place the moving GP"

  ; Moving GP is not still set
  set initial-GP-set false

  ; Control boolean for static GPs
  set static-GP-set false

  let manual read-from-string user-input "Put 1 for manual version"

  if manual = 1 [
   set manual-version true
  ; Wait for the initial GP
  while [initial-GP-set = false]
  [
    mouse-manager("moving")
  ]
  ]


  ; Clear ticks
  reset-ticks

end


to shuffle-processors
  ask processors [
    rt random 360
    fd patch-size / 25
  ]
end



;-------------------------------PROGRAM----------------------------

to-report mouse-clicked?
  report (mouse-was-down? = true and not mouse-down?)
end

to mouse-manager[trop]
  let mouse-is-down? mouse-down?
  if mouse-clicked?
  [
    add-GP trop 666 666
  ]
  set mouse-was-down? mouse-is-down?
end

to colouring[gp_position]

end

to add-GP[trop hc-x hc-y]
ifelse initial-GP-set = false and static-GP-set = false
  [
    set initial-GP-set true
    ifelse hc-x = 666
    [
    set growing-point min-one-of processors [distancexy mouse-xcor mouse-ycor]
    ]
    [
     set growing-point min-one-of processors [distancexy hc-x hc-y]
    ]

    ask growing-point
    [
      set label "Walker"
      pd
      set pen-size 4
      set breed gps
      set color red
      set shape "circle"
      set gp_type "moving"
      set concentration 0
      set visited true
      set gp_pos -1
      set label-color color
    ]
  ]
  [
    ifelse hc-x = 666
    [
    set growing-point min-one-of processors [distancexy mouse-xcor mouse-ycor]
    ]
    [
      set growing-point min-one-of processors [distancexy hc-x hc-y]
    ]
    ask growing-point
    [
      set label "GP"
      ifelse trop = "plus" [
        set breed gps
        set color green
        set shape "circle"
        set gp_type "plus"
        set gp_pos gp-counter
        set visited false
      ][
        set breed gps
        set color yellow
        set shape "circle"
        set gp_type "minus"
        set gp_pos gp-counter
        set visited false
      ]
      set label-color color
    ]
    set gp-counter gp-counter + 1
  set static-GP-set true
  ]
end


to create-ortho-plus
  let radius read-from-string user-input "Size of the ortho plus radius?"
  while [static-GP-set = false]
  [
    mouse-manager("plus")
  ]
  set static-GP-set false

  calculate-concentrations radius ; calculate concentrations of processors in the defined radius
end

to create-ortho-minus
  let radius read-from-string user-input "Size of the ortho minus radius?"
  while [static-GP-set = false]
  [
    mouse-manager("minus")
  ]
  set static-GP-set false

  calculate-concentrations radius ; calculate concentrations of processors in the defined radius
end

to calculate-concentrations [radius]
  ask growing-point[
    let tmp gp_pos
    set concentrations array:from-list n-values max_number_of_gps [0] ; we set the init values of concentrations
    array:set concentrations tmp radius ; we set the concentration for the GP as well
    ask other processors in-radius radius[
      array:set concentrations tmp radius - (distance myself) ;we calculate the concentrations for processors in the given radius
      let new_con array:item concentrations tmp ; we use this so we leave the colour of the strongest concentration in processors
      let need-change true
      foreach n-values max_number_of_gps [ i -> i ] [ i -> if array:item concentrations i > new_con [set need-change false]]
      if need-change and breed != gps[
        set color tmp * 10 - array:item concentrations tmp * 0.25 ; colouring
      ]
    ]
    if manual-version = true or hc_minus = true
    [
      ask other gps in-radius radius[
        array:set concentrations tmp radius - (distance myself) ;we calculate the concentrations for moving gps in the given radius
      ]
    ]
  ]
end


to go
  ifelse not done[
    ask gps with [gp_type = "moving"][
      ask gps with [gp_pos = act_gp] [
        set act_gp_type gp_type
      ]
      ifelse act_gp_type = "plus" [
        let tmp concentration ; so we move only to processors with higher concentration than the one at the current patch
        while[not any? other turtles in-radius rad with [array:item concentrations act_gp > tmp]][ ; increasing the radius till we find suitable processor for the movement
          set rad rad + 1
        ]
        set concentration [array:item concentrations act_gp] of max-one-of other turtles in-radius rad [array:item concentrations act_gp]
        move-to max-one-of other turtles in-radius rad [array:item concentrations act_gp] ; we move
        ask turtles-here [set color red]
        if any? other gps-here [ ; if there are 2 GP at this patch -> we are in active GP
          ifelse manual-version = true
          [
            set act_gp act_gp + 1  ; we set the number of the next active GP
          ]
          [
            set hc-counter hc-counter + 1 ; global iterator for hardcoded version
            if hc-counter < length active-gp-list ; while the iterator is smaller then the length of the hardcoded growing points list
            [
              set act_gp item hc-counter active-gp-list ; set active gp to the one that is at the iterator's place in the list
            ]
          ]
          set concentration 0
        ]

        ifelse manual-version = true
        [
          ask other gps-here [set visited true]
          set rad 0
          if not any? gps with [visited = false] [set done true]
        ]
        [
          set rad 0
          if hc-counter = length active-gp-list [set done true] ; if we went through the whole predefined list we are done
        ]
      ][ ;gp_type = "minus"
        let already_set false
        let tmp concentration ; so we move only to processors with higher concentration than the one at the current patch
        if tmp = 0 [ ;setting first concentration
          if act_gp = 0 and array:item concentrations act_gp = 0 [
            print "error - zacinam mimo radius" ; it's an error if processor here has concentration 0 -> walker is not in any radius
            set done true
            stop
          ]

          ifelse not any? processors-here [
            if any? other gps-here[
              let err true
              ask other gps-here [
                if array:item concentrations act_gp != 0 [
                  set err false
              ]]
              if err [
                print "error - zacinam mimo radius" ; it's an error if processor here has concentration 0 -> walker is not in any radius
                set done true
                stop
            ]]
              while[not any? other processors in-radius rad with [array:item concentrations act_gp > 0]][ ; increasing the radius till we find suitable processor for the movement
                set rad rad + 1
              ]
              set concentration [array:item concentrations act_gp] of min-one-of other processors in-radius rad [array:item concentrations act_gp]
              move-to min-one-of other processors in-radius rad [array:item concentrations act_gp] ; we move
              ask turtles-here [set color red]
              set rad 0
              set already_set true
              if [array:item concentrations act_gp] of min-one-of other processors in-radius rad [array:item concentrations act_gp] = 0[
                ask gps with [gp_pos = act_gp][set visited true]
                set concentration 0
                ifelse manual-version = true
          [
            set act_gp act_gp + 1  ; we set the number of the next active GP
          ]
          [
            set hc-counter hc-counter + 1 ; global iterator for hardcoded version
            if hc-counter < length active-gp-list ; while the iterator is smaller then the length of the hardcoded growing points list
            [
              set act_gp item hc-counter active-gp-list ; set active gp to the one that is at the iterator's place in the list
            ]
          ]
                set rad 0
                if not any? gps with [visited = false] [set done true]
              ]

          ][
            set concentration [array:item concentrations act_gp] of min-one-of processors-here [array:item concentrations act_gp]
          ]



          set tmp concentration
          ask turtles-here [set color red]
        ]
        if not already_set[
          while[not any? other processors in-radius rad with [array:item concentrations act_gp < tmp]][ ; increasing the radius till we find suitable processor for the movement
            set rad rad + 1
          ]
          ifelse [array:item concentrations act_gp] of min-one-of other processors in-radius rad [array:item concentrations act_gp] = 0[
            ask gps with [gp_pos = act_gp][set visited true]
            set concentration 0
             ifelse manual-version = true
          [
            set act_gp act_gp + 1  ; we set the number of the next active GP
          ]
          [
            set hc-counter hc-counter + 1 ; global iterator for hardcoded version
            if hc-counter < length active-gp-list ; while the iterator is smaller then the length of the hardcoded growing points list
            [
              set act_gp item hc-counter active-gp-list ; set active gp to the one that is at the iterator's place in the list
            ]
          ]
            set rad 0
            if not any? gps with [visited = false] [set done true]
          ][
            set concentration [array:item concentrations act_gp] of min-one-of other processors in-radius rad [array:item concentrations act_gp]
            move-to min-one-of other processors in-radius rad [array:item concentrations act_gp] ; we move
            ask turtles-here [set color red]
            set rad 0
          ]
        ]
      ]
    ]
    tick
  ][
    print "we are done"
    stop
  ]
end


to hide-radius
  ask processors with [breed != gps][
    set color grey
  ]
end


to visualize-radius
  ask processors with [breed != gps][
    let max_con 0
    let pos 0
    let need-change false
    ; we set the colour for the strongest concentration of each processor
    foreach n-values max_number_of_gps [ i -> i ] [ i -> if array:item concentrations i > max_con [
      set max_con array:item concentrations i
      set pos i
      set need-change true]]

      if need-change [
        set color pos * 10 - max_con * 0.25
      ]
  ]

end




to hardcoded_plus [hc-radius hc-x hc-y] ; function to bypass mouse clicks and pass hardcoded coordinates as parameters
  add-GP "plus" hc-x hc-y
  calculate-concentrations hc-radius
end

to hardcoded_minus [hc-radius hc-x hc-y]
  add-GP "minus" hc-x hc-y
  calculate-concentrations hc-radius
end

to house_plus
  set manual-version false
  set active-gp-list [0 1 2 0 3 4 1 3 2] ;list of gps to visit in this particular order
 add-GP "moving" -20 -20 ;mover
  let house_points  [[-20 -20] [20 20] [20 -20] [-20 20] [0 43]] ; hardcoded points whose indexec correspond with the active-gp-list
  foreach house_points [ i ->  hardcoded_plus 30 item 0 i item 1 i] ; set radius and xy coordinates for every point
  stop
end

to heart_plus
  set manual-version false
  set active-gp-list [0 1 2 3 4 5 6 7 8 9 0]
  add-GP "moving" 0 20
  let heart_points  [[0 20] [10 30] [20 30] [30 20] [30 0] [0 -30] [-30 0] [-30 20] [-20 30] [-10 30]]
  foreach heart_points [ i ->  hardcoded_plus 30 item 0 i item 1 i]
  stop
end

to house_minus
  set manual-version false
  set hc_minus true
  set active-gp-list [0 1 2 0 3 4 1 3 2] ;list of gps to visit in this particular order
 add-GP "moving" -20 -20 ;mover
  let house_points  [[-20 -20] [20 20] [20 -20] [-20 20] [0 43]] ; hardcoded points whose indexec correspond with the active-gp-list
  foreach house_points [ i ->  hardcoded_minus 60 item 0 i item 1 i] ; set radius and xy coordinates for every point
  stop
end

to heart_minus
  set manual-version false
  set hc_minus true
  set active-gp-list [0 1 2 3 4 5 6 7 8 9 0]
  add-GP "moving" 0 20
  let heart_points  [[0 20] [10 30] [20 30] [30 20] [30 0] [0 -30] [-30 0] [-30 20] [-20 30] [-10 30]]
  foreach heart_points [ i ->  hardcoded_minus 60 item 0 i item 1 i]
  stop
end
@#$#@#$#@
GRAPHICS-WINDOW
262
19
977
735
-1
-1
7.0
1
10
1
1
1
0
1
1
1
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
25
25
88
58
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
25
64
197
97
number-processors
number-processors
0
10151
5310.0
1
1
NIL
HORIZONTAL

BUTTON
50
103
186
136
visualize-radius
visualize-radius
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
51
140
185
173
hide-radius
hide-radius
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
135
26
198
59
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
47
202
182
235
NIL
create-ortho-plus
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
45
243
183
276
NIL
create-ortho-minus
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
24
321
196
354
max_number_of_gps
max_number_of_gps
0
12
12.0
1
1
NIL
HORIZONTAL

BUTTON
66
395
160
428
NIL
house_plus\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
69
452
159
485
NIL
heart_plus
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
67
533
170
566
NIL
house_minus
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
69
589
169
622
NIL
heart_minus\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

This section could give a general understanding of what the model is trying to show or explain.

## HOW IT WORKS

This section could explain what rules the agents use to create the overall behavior of the model.

## HOW TO USE IT

This section could explain how to use the model, including a description of each of the items in the interface tab.

## THINGS TO NOTICE

This section could give some ideas of things for the user to notice while running the model.

## THINGS TO TRY

This section could give some ideas of things for the user to try to do (move sliders, switches, etc.) with the model.

## EXTENDING THE MODEL

This section could give some ideas of things to add or change in the procedures tab to make the model more complicated, detailed, accurate, etc.

## NETLOGO FEATURES

This section could point out any especially interesting or unusual features of NetLogo that the model makes use of, particularly in the Procedures tab.  It might also point out places where workarounds were needed because of missing features.

## RELATED MODELS

This section could give the names of models in the NetLogo Models Library or elsewhere which are of related interest.

## CREDITS AND REFERENCES

This section could contain a reference to the model's URL on the web if it has one, as well as any other necessary credits or references.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
