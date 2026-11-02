from pathlib import Path
from html import escape
import json
out=Path(__file__).resolve().parent
concepts=[dict(id='A',name='PORCELAIN DAYLIGHT',bg='#f4f0e7',panel='#fffdf8',ink='#153b3d',accent='#126f70',muted='#566e6d',palette=['#ef836f','#60b7a7','#e8b957','#7e91c8'],radius=18,style='Precision • daylight • ceramic',note='Etched glass / long soft shadows / quiet scientific detail'),dict(id='B',name='OPTICAL NOCTURNE',bg='#10191f',panel='#192b32',ink='#eef4e8',accent='#cbe68b',muted='#8ea8aa',palette=['#f39080','#69d2c4','#edc36a','#bba7e2'],radius=36,style='Exhibition • rim light • smoked glass',note='Luminous edges / deep ink field / sculptural optical plinth'),dict(id='C',name='LIVING CONSERVATORY',bg='#e5eee2',panel='#f6f3e5',ink='#28483c',accent='#426b49',muted='#586e59',palette=['#db927b','#7ab5a0','#d9b45c','#a69abb'],radius=55,style='Organic • frosted • botanical',note='Frosted vessels / diffused canopy / tactile paper labels')]
def rect(x,y,w,h,fill,r=0,extra=''):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" {extra}/>'
def text(x,y,t,size=16,color=None,extra=''):return f'<text x="{x}" y="{y}" font-family="sans-serif" font-size="{size}" fill="{color or c["ink"]}" {extra}>{escape(t)}</text>'
def tube(x,y,w,h,layers,unique):
 r=w*.45 if c['id']!='A' else w*.35
 shape=f'M{x+4},{y} H{x+w-4} V{y+h-r} Q{x+w-4},{y+h} {x+w/2},{y+h} Q{x+4},{y+h} {x+4},{y+h-r} Z'
 if c['id']=='C': shape=f'M{x+12},{y} H{x+w-12} V{y+35} Q{x+w},{y+55} {x+w-3},{y+h-26} Q{x+w-3},{y+h} {x+w/2},{y+h} Q{x+3},{y+h} {x+3},{y+h-26} Q{x},{y+55} {x+12},{y+35} Z'
 s=f'<defs><clipPath id="t{unique}"><path d="{shape}"/></clipPath></defs>'
 s+=f'<ellipse cx="{x+w/2}" cy="{y+h+9}" rx="{w*.65}" ry="6" fill="{c["ink"]}" opacity=".12"/>'
 s+=f'<path d="{shape}" fill="url(#glass)" stroke="{c["muted"]}" stroke-width="1.3"/>'
 s+=f'<g clip-path="url(#t{unique})">'
 unit=(h-16)/4
 for i,col in enumerate(layers):
  yy=y+h-5-(i+1)*unit
  s+=rect(x+6,yy,w-12,unit+1,c['palette'][col]);s+=f'<ellipse cx="{x+w/2}" cy="{yy+1}" rx="{(w-12)/2}" ry="3" fill="#fff" opacity=".23"/>'
  for d in range(col+1):s+=f'<circle cx="{x+12+d*4}" cy="{yy+unit*.55}" r="1.1" fill="{c["ink"]}" opacity=".62"/>'
 s+=rect(x+6,y,w-12,h,'url(#sheen)',0,'opacity="'+('0.32' if c['id']=='B' else '0.12')+'"')
 s+='</g>'
 s+=f'<path d="M{x+9},{y+9} V{y+h-20}" stroke="white" stroke-width="3" opacity=".58" stroke-linecap="round"/>'
 s+=f'<ellipse cx="{x+w/2}" cy="{y}" rx="{w/2-2}" ry="4" fill="none" stroke="{c["muted"]}" stroke-width="1.5"/>'
 if c['id']=='A':
  for tick in range(1,5):s+=f'<path d="M{x+w-9},{y+tick*h/5} h-4" stroke="{c["ink"]}" opacity=".3"/>'
 return s
for c in concepts:
 s=f'<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="1250" viewBox="0 0 1440 1250"><defs><linearGradient id="glass"><stop stop-color="white" stop-opacity=".5"/><stop offset=".22" stop-color="white" stop-opacity=".03"/><stop offset=".8" stop-color="white" stop-opacity=".06"/><stop offset="1" stop-color="white" stop-opacity=".5"/></linearGradient><linearGradient id="sheen"><stop stop-color="#000" stop-opacity=".7"/><stop offset=".25" stop-color="#fff" stop-opacity="0"/><stop offset=".75" stop-color="#fff" stop-opacity=".5"/><stop offset="1" stop-color="#000" stop-opacity=".2"/></linearGradient><radialGradient id="light"><stop stop-color="{c["accent"]}" stop-opacity=".22"/><stop offset="1" stop-color="{c["accent"]}" stop-opacity="0"/></radialGradient></defs>'
 s+=rect(0,0,1440,1250,c['bg'])+text(52,49,c['id']+' / '+c['name'],30)+text(52,78,'ORIGINAL DESIGN MOCKUPS — NOT GODOT CAPTURES — OWNER SELECTION PENDING',12,c['muted'])
 for n,label in enumerate(['HOME','GAMEPLAY','VICTORY']):
  x=52+n*350;y=120;w=306;h=680
  s+=text(x,y-14,label,12,c['muted'])+rect(x,y,w,h,c['panel'],c['radius'])
  s+=f'<ellipse cx="{x+153}" cy="{y+285}" rx="145" ry="255" fill="url(#light)"/>'
  if c['id']=='C':
   s+=f'<path d="M{x},{y+370} Q{x+150},{y+190} {x+306},{y+350} V{y+680} H{x}Z" fill="{c["bg"]}" opacity=".7"/>'
  if c['id']=='A':s+=f'<path d="M{x+20},{y+450} H{x+286}" stroke="{c["muted"]}" opacity=".25"/>'
  if c['id']=='B':
   s+=f'<circle cx="{x+153}" cy="{y+330}" r="132" fill="none" stroke="{c["accent"]}" stroke-width="1" opacity=".35"/>'
  if c['id']=='B':s+=f'<ellipse cx="{x+153}" cy="{y+465}" rx="130" ry="23" fill="#0c1217"/>'
  s+=text(x+25,y+38,'LAYER SORT' if n==0 else ('LEVEL 12     ·     8 MOVES' if n==1 else 'CLASSIC / LEVEL 12'),13,c['muted'])
  if n==0:
   s+=text(x+25,y+109,'A moment',34)+text(x+25,y+150,'of clarity.',34)
   for i in range(3):s+=tube(x+63+i*62,y+240+(i%2)*22,46,196,[i,i,(i+1)%3,(i+2)%3],f'{n}-{i}')
   s+=rect(x+24,y+510,258,62,c['accent'],c['radius']/2)+text(x+48,y+548,'PLAY CLASSIC · 12',18,c['bg'])
   s+=text(x+30,y+610,'Level Map     Settings     About',14,c['muted'])
  elif n==1:
   s+=text(x+25,y+92,'Bring colour into balance.',16)
   for i in range(5):
    tx=x+24+i*53; ty=y+225; th=220; tw=43
    if c['id']=='C': tx=x+55+(i%3)*70; ty=y+135+(i//3)*185; th=155; tw=55
    s+=tube(tx,ty,tw,th,([i%3,(i+1)%3,(i+2)%3,i%3] if i<3 else []),f'{n}-{i}')
   s+=text(x+26,y+503,'Select a tube. Then its destination.',13,c['muted'])
   s+=rect(x+24,y+570,120,56,c['bg'],15)+rect(x+162,y+570,120,56,c['bg'],15)+text(x+57,y+604,'Undo',17)+text(x+189,y+604,'Restart',17)
  else:
   s+=text(x+125,y+170,'✦',70,c['accent'])+text(x+32,y+250,'Beautifully sorted.',27)+text(x+45,y+286,'One earned star · 18 moves',14,c['muted'])
   for i in range(3):s+=tube(x+70+i*59,y+340,40,120,[i]*4,f'{n}-{i}')
   s+=rect(x+24,y+510,258,62,c['accent'],c['radius']/2)+text(x+63,y+548,'NEXT LEVEL · 13',18,c['bg'])
   s+=text(x+70,y+611,'Replay       Map',16,c['muted'])
 s+=text(1120,145,'MATERIAL STUDY',14)+tube(1145,200,150,330,[0,1,2,3],'hero')
 s+=text(1108,570,'Double rim / meniscus',15)+text(1108,597,'Shape marks survive colour loss',12,c['muted'])
 s+=text(1250,650,'المستوى ١٢',25,extra='text-anchor="middle" direction="rtl"')+text(1140,683,'Arabic specimen / fallback',12,c['muted'])
 s+=text(52,866,c['style'],23)+text(52,903,c['note'],17,c['muted'])
 for i,col in enumerate(c['palette']+[c['bg'],c['ink'],c['accent']]):s+=rect(52+i*130,940,110,65,col,12)+text(52+i*130,1030,col,13)
 s+=text(52,1100,'Typography proposal: Manrope + Noto Sans Arabic. Preview uses host fallback; approve font proofs separately.',16)
 s+=text(52,1140,'2D / baked lighting / no realtime refraction / 48dp-equivalent targets / reduced-motion static surfaces',16,c['muted'])
 s+=text(52,1201,'Next action: choose an art direction. These assets are not installed in the Android product.',16)
 s+='</svg>'
 (out/(c['id']+'-concept.svg')).write_text(s)
(out/'tokens.json').write_text(json.dumps({'status':'PROPOSED_NOT_APPROVED','units':'720-wide reference pixels; derive dp-equivalent touch bounds on Android','shared':{'spacing':[8,16,24,32,48],'touch_min_dp':48,'press_ms':120,'screen_ms':220,'victory_ms':900,'reduced_motion_ms':100,'tube_glass_layers_max':3,'particles_default':0},'concepts':concepts},indent=2))
