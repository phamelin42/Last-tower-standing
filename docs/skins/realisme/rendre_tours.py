"""Rend les tours de la piste b avec Blender (voir README.md).

Usage : blender --background --factory-startup --python rendre_tours.py -- pierre glace ...
Chemins de travail (hors dépôt, à adapter en tête de fichier) : Kenney Castle Kit, Graveyard Kit et Fantasy Town Kit
décompressés dans /tmp/claude-0/k3d/, textures et HDRI Poly Haven dans /tmp/claude-0/ph/, sortie dans /tmp/claude-0/render/out/.
"""
import bpy,sys,math,mathutils,os,json
K='/tmp/claude-0/k3d/castle-kit/Models/GLB format/'
PH='/tmp/claude-0/ph/'
OUT='/tmp/claude-0/render/out/'
os.makedirs(OUT,exist_ok=True)
THEMES={
 'pierre':   dict(parts=['tower-square-base','tower-square-mid-door','tower-square-top','tower-square-top-roof'],tex='old_stone_wall',tint=(1,1,1,1),scale=1.0,rough=None,flag=(0.1,0.35,0.7,1)),
 'mousse':   dict(parts=['tower-square-base','tower-square-mid-windows','tower-square-top','tower-square-top-roof-high'],tex='mossy_brick',tint=(1,1,1,1),scale=1.0,flag=None),
 'fissure':  dict(parts=['tower-hexagon-base','tower-hexagon-mid','tower-hexagon-top','tower-hexagon-roof'],tex='cracked_red_ground',tint=(0.35,0.3,0.3,1),scale=0.8,flag=(0.8,0.1,0.05,1)),
 'glace':    dict(parts=['tower-square-base','tower-square-mid-windows','tower-square-top','tower-square-top-roof-high'],tex='snow_02',tint=(0.55,0.8,1.0,1),scale=1.0,metal=0.0,rough=0.15,flag=(0.8,0.95,1,1)),
 'bois':     dict(parts=['tower-hexagon-base','tower-hexagon-mid','tower-hexagon-top','tower-hexagon-roof'],tex='dark_planks',tint=(1,0.85,0.7,1),scale=1.2,flag=(0.1,0.35,0.7,1)),
 'or':       dict(parts=['tower-square-base','tower-square-mid-windows','tower-square-top','tower-square-top-roof'],tex='marble_01',tint=(1.0,0.78,0.25,1),scale=1.0,metal=1.0,rough=0.25,flag=(0.6,0.05,0.1,1)),
 'brique':   dict(parts=['tower-square-base','tower-square-mid-door','tower-square-top','tower-square-top-roof'],tex='castle_brick_02_red',tint=(1,1,1,1),scale=1.0,flag=(0.9,0.85,0.7,1)),
 'metal':    dict(parts=['tower-hexagon-base','tower-hexagon-mid','tower-hexagon-top','tower-hexagon-roof'],tex='rusty_metal_03',tint=(1,1,1,1),scale=1.0,metal=0.9,rough=None,flag=None),
 'siege':    dict(parts=['tower-square-base','tower-square-mid-windows','tower-square-top','tower-square-top-roof'],tex='old_stone_wall',tint=(1,1,1,1),scale=1.0,flag=(0.1,0.35,0.7,1),extra=('siege-ram',(1.3,-0.9,0),-0.5)),
 'braise':   dict(parts=['tower-square-base','tower-square-mid-windows','tower-square-top','tower-square-top-roof'],tex='burned_ground_01',tint=(0.6,0.35,0.25,1),scale=1.0,flag=(1,0.45,0.05,1)),

 'ossuaire': dict(parts=['tower-square-base','tower-square-mid-windows','tower-square-top','tower-square-top-roof'],tex='old_stone_wall',tint=(0.45,0.45,0.5,1),scale=1.0,flag=None,props=[('/tmp/claude-0/k3d/graveyard-kit/Models/GLB format/','gravestone-cross',(1.35,-0.95,0),0.4,2.4,'marble_01',(0.75,0.75,0.8,1)),('/tmp/claude-0/k3d/graveyard-kit/Models/GLB format/','gravestone-broken',(-1.4,-1.0,0),-0.3,2.4,'rock_boulder_cracked',(0.8,0.8,0.8,1)),('/tmp/claude-0/k3d/graveyard-kit/Models/GLB format/','fire-basket',(1.3,1.0,0),0,2.6,'rusty_metal_03',(0.5,0.45,0.4,1)),('/tmp/claude-0/k3d/graveyard-kit/Models/GLB format/','pillar-obelisk',(-1.3,0.9,0),0,1.7,'old_stone_wall',(0.5,0.5,0.55,1))]),
 'comptoir': dict(parts=['tower-square-base','tower-square-mid-door','tower-square-top','tower-square-top-roof'],tex='brown_planks_03',tint=(1,0.9,0.8,1),scale=1.2,flag=(0.7,0.1,0.1,1),props=[('/tmp/claude-0/k3d/fantasy-town-kit/Models/GLB format/','stall-red',(1.5,-1.0,0),0.5,2.3,'brown_planks_03',(1,0.85,0.7,1)),('/tmp/claude-0/k3d/fantasy-town-kit/Models/GLB format/','cart',(-1.5,-1.0,0),-0.4,2.3,'dark_planks',(1,0.9,0.8,1)),('/tmp/claude-0/k3d/fantasy-town-kit/Models/GLB format/','banner-green',(-1.2,1.1,0),0,2.1,'castle_brick_02_red',(1,1,1,1))]),
}
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
def img(path,cs='sRGB'):
    i=bpy.data.images.load(path); i.colorspace_settings.name=cs; return i
def material(name,cfg):
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new('ShaderNodeOutputMaterial'); bsdf=nt.nodes.new('ShaderNodeBsdfPrincipled')
    tc=nt.nodes.new('ShaderNodeTexCoord'); mp=nt.nodes.new('ShaderNodeMapping')
    s=cfg.get('scale',1.0); mp.inputs['Scale'].default_value=(s,s,s)
    nt.links.new(tc.outputs['Object'],mp.inputs['Vector'])
    def tex(path,cs):
        t=nt.nodes.new('ShaderNodeTexImage'); t.image=img(path,cs); t.projection='BOX'; t.projection_blend=0.25
        nt.links.new(mp.outputs['Vector'],t.inputs['Vector']); return t
    d=tex(PH+cfg['tex']+'/diff.jpg','sRGB')
    mix=nt.nodes.new('ShaderNodeMix'); mix.data_type='RGBA'; mix.blend_type='MULTIPLY'; mix.inputs['Factor'].default_value=1.0
    nt.links.new(d.outputs['Color'],mix.inputs['A']); mix.inputs['B'].default_value=cfg['tint']
    nt.links.new(mix.outputs['Result'],bsdf.inputs['Base Color'])
    n=tex(PH+cfg['tex']+'/nor.jpg','Non-Color'); nm=nt.nodes.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value=1.0
    nt.links.new(n.outputs['Color'],nm.inputs['Color']); nt.links.new(nm.outputs['Normal'],bsdf.inputs['Normal'])
    if cfg.get('rough') is None and os.path.exists(PH+cfg['tex']+'/rough.jpg'):
        r=tex(PH+cfg['tex']+'/rough.jpg','Non-Color'); nt.links.new(r.outputs['Color'],bsdf.inputs['Roughness'])
    else: bsdf.inputs['Roughness'].default_value=cfg.get('rough',0.6) or 0.6
    bsdf.inputs['Metallic'].default_value=cfg.get('metal',0.0)
    nt.links.new(bsdf.outputs['BSDF'],out.inputs['Surface']); return m
def flat(name,col,rough=0.6):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=col; b.inputs['Roughness'].default_value=rough; return m
def load(n,loc=(0,0,0),rot=0.0,wide=1.0,kit=None):
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=(kit or K)+n+'.glb')
    new=[o for o in bpy.context.scene.objects if o not in before]
    root=mathutils.Matrix.Translation(loc)@mathutils.Matrix.Rotation(rot,4,'Z')@mathutils.Matrix.Diagonal((wide,wide,1.0,1.0))
    for o in new:
        if o.parent is None: o.matrix_world=root@o.matrix_world
    return [o for o in new if o.type=='MESH']
def assign(objs,mat):
    for o in objs:
        o.data.materials.clear(); o.data.materials.append(mat)
def bbox(objs):
    mn=mathutils.Vector((1e9,)*3);mx=mathutils.Vector((-1e9,)*3)
    for o in objs:
        for c in o.bound_box:
            w=o.matrix_world@mathutils.Vector(c); mn=mathutils.Vector(map(min,mn,w)); mx=mathutils.Vector(map(max,mx,w))
    return mn,mx
HT={'tower-square-base':1.01,'tower-square-mid':1.01,'tower-square-mid-windows':1.01,'tower-square-mid-door':1.01,'tower-square-top':0.3,'tower-square-top-roof':1.0,'tower-square-top-roof-high':1.35,'tower-square-roof':2.01,'tower-hexagon-base':1.31,'tower-hexagon-mid':0.46,'tower-hexagon-top':0.13,'tower-hexagon-roof':0.83}
def build(name,cfg,size):
    reset(); s=bpy.context.scene
    tower=[];z=0.0
    for p in cfg['parts']:
        o=load(p,(0,0,z),0.0,1.6); tower+=o; z+=HT[p]
    assign(tower,material(name,cfg))
    allobjs=list(tower)
    if cfg.get('flag'):
        f=load('flag-pennant',(0,0,z-0.02),0.0,1.4); assign(f,flat('flag',cfg['flag'])); allobjs+=f; z+=0.87
    if cfg.get('extra'):
        n,loc,rot=cfg['extra']; e=load(n,(loc[0]*1.5,loc[1]*1.5,0),rot,1.2); assign(e,material(name+'x',dict(cfg,tex='dark_planks',scale=1.2,tint=(0.8,0.7,0.6,1)))); allobjs+=e
    for (kit,n,loc,rot,sc,tx,tn) in cfg.get('props',[]):
        o=load(n,loc,rot,sc,kit); assign(o,material(name+n,dict(cfg,tex=tx,tint=tn,scale=1.0,metal=0.0,rough=None))); allobjs+=o
    mn,mx=bbox(allobjs)
    # sol (ombre seulement)
    bpy.ops.mesh.primitive_plane_add(size=12,location=(0,0,-0.001)); g=bpy.context.object; g.is_shadow_catcher=True
    # lumières
    bpy.ops.object.light_add(type='SUN',location=(4,-5,8)); sun=bpy.context.object; sun.data.energy=4.5; sun.data.angle=math.radians(6); sun.rotation_euler=(math.radians(50),0,math.radians(35))
    w=bpy.data.worlds.new('w'); s.world=w; w.use_nodes=True
    e=w.node_tree.nodes.new('ShaderNodeTexEnvironment'); e.image=img('/tmp/claude-0/ph/belfast_open_field_1k.hdr','Linear Rec.709')
    bg=w.node_tree.nodes['Background']; w.node_tree.links.new(e.outputs['Color'],bg.inputs['Color']); bg.inputs['Strength'].default_value=0.9
    # caméra orthographique, légère plongée
    cx=(mn.x+mx.x)/2;cy=(mn.y+mx.y)/2;cz=(mn.z+mx.z)/2
    el=math.radians(28);az=math.radians(38)
    d=20
    cam_loc=mathutils.Vector((cx+d*math.cos(el)*math.sin(az),cy-d*math.cos(el)*math.cos(az),cz+d*math.sin(el)))
    bpy.ops.object.camera_add(location=cam_loc); cam=bpy.context.object; s.camera=cam; cam.data.type='ORTHO'
    dirv=mathutils.Vector((cx,cy,cz))-cam_loc; cam.rotation_euler=dirv.to_track_quat('-Z','Y').to_euler()
    h=(mx.z-mn.z)*math.cos(el)+ (max(mx.x-mn.x,mx.y-mn.y))*math.sin(el)*1.0
    cam.data.ortho_scale=max(h*1.12,(mx.x-mn.x)*2.0+0.6)*size[1]/size[1]
    r=s.render; r.engine='CYCLES'; s.cycles.device='CPU'; s.cycles.samples=40; s.cycles.use_denoising=True
    r.resolution_x,r.resolution_y=size; r.film_transparent=True; r.image_settings.file_format='PNG'; r.image_settings.color_mode='RGBA'
    s.view_settings.view_transform='Filmic' if 'Filmic' in [v.identifier for v in s.view_settings.bl_rna.properties['view_transform'].enum_items] else 'Standard'
    r.filepath=OUT+name+'.png'; bpy.ops.render.render(write_still=True)
    try:
        from PIL import Image
    except Exception: pass
names=sys.argv[sys.argv.index('--')+1:] or list(THEMES)
for n in names: build(n,THEMES[n],(512,768)); print('RENDU',n)
