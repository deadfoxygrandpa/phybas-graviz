{- |
Module      :  Physics
Description :  Definition and drawing of a graph.
Copyright   :  (c) Jeff Smits
License     :  GPL-3.0

Maintainer  :  jeff.smits@gmail.com
Stability   :  experimental
Portability :  portable

 | ---------------------------------------------------------------------- |
 | This program is free software: you can redistribute it and/or modify   |
 | it under the terms of the GNU General Public License as published by   |
 | the Free Software Foundation, either version 3 of the License, or      |
 | (at your option) any later version.                                    |
 |                                                                        |
 | This program is distributed in the hope that it will be useful,        |
 | but WITHOUT ANY WARRANTY; without even the implied warranty of         |
 | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          |
 | GNU General Public License for more details.                           |
 |                                                                        |
 | You should have received a copy of the GNU General Public License      |
 | along with this program.  If not, see <http://www.gnu.org/licenses/>.  |
 | ---------------------------------------------------------------------- |

References:

[1] Wolfram|Alpha, URL: https://www.wolframalpha.com/input/?i=density+of+polyester&a=*DPClash.MaterialEC.polyester-_**Polyester.TS--
[2] Wikipedia, URL: https://en.wikipedia.org/wiki/Water_(molecule)#Density_of_water_and_ice
[3] Wikipedia, URL: https://en.wikipedia.org/wiki/Drag_coefficient
[4] Peter Eades. A heuristic for graph drawing. Congressus Numerantium, 42:149–160, 1984. (unchecked reference -don't have access to the original paper- used quote from http://cs.brown.edu/~rt/gdhandbook/chapters/force-directed.pdf)
-}

module Physics where

import Dict    (Dict)
import Dict    as D
import Set     (Set)
import Set     as S
import Point2D (Point2D)
import Point2D as P
import Graph (Vector2D, Node, Edge, Graph)

nodeConstants  = { mass = 10, radius = 3 }
forceConstants = { repulsion = 1000000, springConstant = 50, equilibriumLength = 60 }

precision = 1000000
small_value = 1 / (precision^2)

-- delta of the position of two nodes {- plus a small pseudorandom value -}
positionDelta : Node -> Node -> Point2D
positionDelta from to = P.e_min to.pos from.pos
{-
  let d a b = (toFloat a) / (toFloat b)
      r   = P.carthesian (from.nid `d` to.nid) (to.nid `d` (to.nid - from.nid))
      srv = P.mul r small_value -- small (pseudo-)random value
  in P.e_pls srv <|
-}


repulsion : Graph -> Node -> Vector2D
repulsion g n =
  let r _ cn f =
    if cn.nid == n.nid
      then f
      else
        let d = positionDelta n cn
            (l,u) = P.breakDown d
            f' = -(forceConstants.repulsion / l^2)
        in P.e_pls f <| P.mul u f'
  in D.foldl r P.zero g.nodes

nodeStep : Float -> Graph -> Graph
nodeStep delta g =
  let mrf  = D.map (repulsion g) g.nodes
      appRep n =
        let appRep' f =
          let (l,u) = P.breakDown f
              vl = l * delta / nodeConstants.mass
              v = P.mul u vl
          in{ n | vel <- P.e_pls n.vel v }
        in maybe n appRep' <| D.lookup n.nid mrf
  in { g | nodes <- D.map appRep g.nodes }

attraction : Graph -> Node -> Vector2D
attraction g n =
  let a _ cn f =
    if cn.nid == n.nid
      then f
      else
        let ei = S.union (S.intersect n.edges cn.bEdges) (S.intersect n.bEdges cn.edges)
        in
          if S.toList ei == []
          then f
          else
            let d = positionDelta n cn
                (l,u) = P.breakDown d
                f' = forceConstants.springConstant * (l - forceConstants.equilibriumLength)
            in P.e_pls f <| P.mul u f'
  in D.foldl a P.zero g.nodes

edgeStep : Float -> Graph -> Graph
edgeStep delta g =
  let maf  = D.map (attraction g) g.nodes
      appAttr n =
        let appAttr' f =
          let (l,u) = P.breakDown f
              vl = l * delta / nodeConstants.mass
              v = P.mul u vl
          in{ n | vel <- P.e_pls n.vel v }
        in maybe n appAttr' <| D.lookup n.nid maf
  in { g | nodes <- D.map appAttr g.nodes }

drag : Graph -> Node -> Vector2D
drag _ n =
  let (l,u) = P.breakDown n.vel

      rho = 998.2071   -- kg/m^3 (20 degrees Celsius water [2])
      dF  = 1/3000     -- extra density factor, for tweaking

      dens  = dF * rho -- kg/m^3, density
      coeff = 0.47     -- dimensionless (coefficient for a circular shape [3])
      area  = pi * nodeConstants.radius ^ 2 -- m^2

      f = -(l^2 * dens * coeff * area / 2) -- N
  in P.mul u f

dragStep : Float -> Graph -> Graph
dragStep delta g =
  let mdf  = D.map (drag g) g.nodes
      appDrag n =
        let appDrag' f =
          let (l,u) = P.breakDown f
              vl = l * delta / nodeConstants.mass
              -- don't have drag force change the velocity to anything faster than the last velocity
              vl' = clamp 0 (P.magn n.vel) vl
              v = P.mul u vl'
          in{ n | vel <- P.e_pls n.vel v }
        in maybe n appDrag' <| D.lookup n.nid mdf
  in { g | nodes <- D.map appDrag g.nodes }

velocityStep : Float -> Graph -> Graph
velocityStep delta g =
  let vel  n       = { n | pos <- vel2 n.pos n.vel }
      vel2 pos vel = P.e_pls pos (P.mul vel delta)
  in { g | nodes <- D.map vel g.nodes }

{-
frictionStep : Float -> Graph -> Graph
frictionStep delta g =
  let fric  n   = { n | vel <- fric2 n.vel }
      fric2 vel = P.map fric3 vel
      -- simple rounding off to an amount of digits after the dot.
      fric3 v   = toFloat (round <| precision * v) / precision
  in { g | nodes <- D.map fric g.nodes }
-}


physicsStep : Float -> Graph -> Graph
physicsStep d = if d == 0 then id else velocityStep d . dragStep d . edgeStep d . nodeStep d
