"""The showroom's dimensions, shared by Lobby_Showroom (outside and structure), Lobby_ShowroomHall
(the hall's structure and lighting) and Lobby_ShowroomFit (displays and furniture). Blender space:
X across, -Y the street, Z up; the origin is the footprint's centre on the ground."""

W, D = 132.0, 96.0
X0, X1 = -W / 2, W / 2
Y0, Y1 = -D / 2, D / 2          # Y0: the glass line
WT = 1.5                        # wall thickness
FLOOR = 0.4
CEIL = 22.0
ROOF = 24.0
PARAPET = 26.6
GLASS_TOP = 17.5
PIER = 7.0                      # stone piers at the front corners
DOOR = 8.0                      # half the entrance's width
DOOR_H = 12.5
BAYS = (-50.0, -30.0, -10.0, 10.0, 30.0, 50.0)   # the six elevator bays (x)
BAY_HALF = 7.0
BAY_H = 13.4
PART = 32.0                     # the elevator hall's partition (y)
BAY_Y = (PART + 0.6 + Y1 - WT) / 2               # a bay's centre
COLUMNS = [(x, y) for x in (-44.0, -22.0, 22.0, 44.0) for y in (-24.0, 4.0)]
BEAMS = (-55.0, -33.0, -11.0, 11.0, 33.0, 55.0)
CUTAWAY = (-35.0, -35.0)        # the bunker model's plinth
DOOR_SAMPLE = (37.0, -36.0)     # the blast door on show
