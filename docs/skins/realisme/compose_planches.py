"""Assemble les planches et les maquettes en jeu (voir README.md). Pillow seulement.

Entrées hors dépôt (à adapter en tête de fichier) : sprites de la piste a dans /tmp/claude-0/pa/, rendus Blender dans
/tmp/claude-0/render/out/, capture de tools/vitrines/vitrine_mouvement.tscn par tools/capturer.sh dans /tmp/claude-0/cap_vitrine_mouvement/.
"""
import json,glob,os,zipfile
from PIL import Image,ImageDraw,ImageFont
R='/home/user/Last-tower-standing/docs/skins/realisme/'
PA='/tmp/claude-0/pa/'; RO='/tmp/claude-0/render/out/'
F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',13);FB=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',14)
def trim(im,th=40):
    im=im.convert('RGBA'); bb=im.getchannel('A').point(lambda v:255 if v>th else 0).getbbox(); return im.crop(bb)
def fit(im,h): 
    return im.resize((max(1,round(im.width*h/im.height)),h),Image.LANCZOS)
A=[ # (clé, fichier, titre, auteur, licence, source)
 ('garde_pierre',PA+'medieval-stone-guard-tower-isometric-25d/watchtower_lvl2-exp_full_size.png','Tour de garde en pierre (iso 2.5D)','Colorado Stark','CC0','opengameart.org/content/medieval-stone-guard-tower-isometric-25d'),
 ('garde_bois',PA+'medieval-wooden-guard-tower-isometric-25d/watchtower_wooden_full_size.png','Tour de garde en bois (iso 2.5D)','OpenGameArt (CityBuildingKit)','CC0','opengameart.org/content/medieval-wooden-guard-tower-isometric-25d'),
 ('ancienne',PA+'old-tower/tower.png','Vieille tour moussue','manwesulimo2004','CC0','opengameart.org/content/old-tower'),
 ('brique',PA+'brick-tower-large-sprite/round-tower-sprite.png','Tour ronde en brique','shirish','CC-BY 3.0','opengameart.org/content/brick-tower-large-sprite'),
 ('sombre',PA+'fantasy-tower-dark/tower-textur.png','Tour sombre fantastique','Snabisch','CC0','opengameart.org/content/fantasy-tower-dark'),
 ('steampunk',PA+'steampunk-archer-tower-medieval-series/Medieval_DefenseArcherTower_sprites and source/Medieval_DefenseArcherTower_sprites/Medieval_DefenseArcherTower.png','Tour d\'archers en métal','Snabisch (CityBuildingKit)','CC0','opengameart.org/content/steampunk-archer-tower-medieval-series'),
 ('viking',PA+'viking-archer-tower-low-poly/Viking_DefenseArcherTower_sprites/Viking_DefenseArcherTower.png','Tour viking en bois','OpenGameArt (CityBuildingKit)','CC0','opengameart.org/content/viking-archer-tower-low-poly'),
 ('chateau',PA+'western-european-castle-isometric-25d/castle_7.png','Château d\'Europe de l\'Ouest','Andrettin','CC0','opengameart.org/content/western-european-castle-isometric-25d'),
]
B=[('pierre','Pierre','pierre, granit, tour de pierre, ascète, nue'),('mousse','Mousse ancienne','éternelle, familière'),('fissure','Roche fendue rouge','fissure, cratère'),('glace','Glace','gelée, bouclier'),('bois','Bois','guet, rafistolée, embuscade'),('or','Or','trésor, banquier, dragon avare'),('brique','Brique rouge','sanguine, vainqueur'),('metal','Métal rouillé','ricochet, lame, faux'),('siege','Pierre et bélier','bastion, siège'),('braise','Roche brûlée','braise, tonnerre, artificier'),('ossuaire','Ossuaire (accessoires Graveyard Kit)','ossuaire, survivante, cicatrisée'),('comptoir','Comptoir (accessoires Fantasy Town Kit)','comptoir, chariot, banquier')]
def cell(d,im,x,y,w,h,lines):
    im=fit(im,h-52) if im.width*(h-52)/im.height<=w else im.resize((w,round(im.height*w/im.width)))
    return im
def planche(items,name,titre,cols=4,cw=300,ch=380):
    rows=(len(items)+cols-1)//cols
    sh=Image.new('RGB',(cols*cw,rows*ch+44),(40,42,48));d=ImageDraw.Draw(sh);d.text((10,12),titre,font=FB,fill=(240,240,240))
    for i,(im,l1,l2,l3) in enumerate(items):
        x,y=(i%cols)*cw,(i//cols)*ch+44
        d.rectangle((x+3,y+3,x+cw-3,y+ch-3),outline=(90,95,105))
        im=trim(im)
        s=min((cw-20)/im.width,(ch-80)/im.height); im=im.resize((max(1,int(im.width*s)),max(1,int(im.height*s))),Image.LANCZOS)
        bg=Image.new('RGBA',im.size,(96,128,86,255)); bg.alpha_composite(im)
        sh.paste(bg.convert('RGB'),(x+(cw-im.width)//2,y+8))
        d.text((x+10,y+ch-66),l1,font=FB,fill=(240,240,240));d.text((x+10,y+ch-46),l2,font=F,fill=(170,200,170));d.text((x+10,y+ch-26),l3,font=F,fill=(160,160,170))
    sh.save(R+name);return sh
ia=[(Image.open(f),t,f'{a} · {l}',(s.split('/content/')[-1][:30])) for k,f,t,a,l,s in A]
planche(ia,'planche_piste_a.png','Piste a : sprites 2D réalistes ou peints, CC0 / CC-BY (OpenGameArt)')
ib=[(Image.open(RO+k+'.png'),t,'Kenney + Poly Haven, tous CC0',f'skins : {s}') for k,t,s in B]
planche(ib,'planche_piste_b.png','Piste b : modèles 3D CC0 rendus par Blender (Kenney Castle Kit, textures Poly Haven, HDRI Poly Haven)',cols=6,cw=290,ch=400)
# maquettes en jeu
fr=Image.open('/tmp/claude-0/cap_vitrine_mouvement/image_00000019.png').convert('RGBA')
patch=fr.crop((700,0,930,330)).transpose(Image.FLIP_LEFT_RIGHT)
base=fr.copy(); base.paste(patch,(470,0)); base.paste(patch.crop((0,0,40,330)),(660,0)) 
def mock(im,h=300,cx=577,by=318):
    f=base.copy(); t=fit(trim(im),h); f.alpha_composite(t,(cx-t.width//2,by-t.height)); return f.crop((250,0,900,440))
sel=[('ancienne','Piste a · vieille tour moussue'),('brique','Piste a · tour ronde en brique'),('steampunk','Piste a · tour d\'archers en métal'),('viking','Piste a · tour viking en bois')]
selb=[('pierre','Piste b · pierre'),('glace','Piste b · glace'),('or','Piste b · or'),('siege','Piste b · pierre et bélier')]
Adict={k:f for k,f,*_ in A}
mocks=[]
orig=base.copy()
tiny=fr.crop((250,0,900,440));mocks.append((tiny,'Référence : tour par défaut (Tiny Swords)'))
for k,t in sel: mocks.append((mock(Image.open(Adict[k]),300 if k!='steampunk' and k!='viking' else 230),t))
for k,t in selb: mocks.append((mock(Image.open(RO+k+'.png')),t))
cols=3;cw,ch=650,470
sh=Image.new('RGB',(cols*cw,((len(mocks)+cols-1)//cols)*ch),(30,30,34));d=ImageDraw.Draw(sh)
for i,(im,t) in enumerate(mocks):
    x,y=(i%cols)*cw,(i//cols)*ch; sh.paste(im.convert('RGB'),(x,y)); d.rectangle((x,y+440,x+cw,y+ch),fill=(30,30,34)); d.text((x+10,y+446),t,font=FB,fill=(240,240,240))
sh.save(R+'maquettes_en_jeu.png');print(sh.size)
