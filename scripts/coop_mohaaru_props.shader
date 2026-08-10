// HZM Coop - shaders for the MOHAARU map-pack props added to build mode.
// Extracted verbatim; every name here was checked against all 44 retail archives
// (8507 shader names) and none of them collide, so no renaming was needed.

ammo3
{
	qer_editorimage textures/renan_models/ammobox3.jpg
	{
		map textures/renan_models/ammobox3.jpg
		rgbGen vertex
	}
}

ammo4
{
	qer_editorimage textures/renan_models/ammobox4.jpg
	{
		map textures/renan_models/ammobox4.jpg
		rgbGen vertex
	}
}

bench_posts
{
	qer_editorimage textures/models/custom/bench_posts.tga
	nomipmaps		
	cull none
	{
		map textures/models/custom/bench_posts.tga

		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 512
		rgbGen lightingGrid
	}
}

bookshelf_w
{
	qer_editorimage textures/renan_models/bookshelf_w.jpg
	{
		map textures/renan_models/bookshelf_w.jpg
		rgbGen vertex
	}
}

boxcar_end
{
	qer_editorimage textures/renan_models/boxcar_end.jpg
	{
		map textures/renan_models/boxcar_end.jpg
		rgbGen vertex
	}
}

boxcar_floor
{
	qer_editorimage textures/renan_models/boxcar_floor.jpg
	{
		map textures/renan_models/boxcar_floor.jpg
		rgbGen vertex
	}
}

bulb5
{
	qer_editorimage textures/renan_models/bulb.jpg
	{
		map textures/renan_models/bulb.jpg
		rgbGen vertex
	}
}

bunkerchair_nw
{
	qer_editorimage textures/models/items/bunkerchair.tga

	{
		map textures/models/items/bunkerchair.tga
		rgbGen static
	}
}

c47s_damage
{
	qer_editorimage textures/models/vehicles/c47_damage_tail/C47_damage.tga
	{
		map textures/models/vehicles/c47_damage_tail/C47_damage.tga
		alphafunc GE128
		rgbGen lightingSpherical
	}
}

c47s_prop
{
	qer_editorimage textures/models/vehicles/c47_damage_all/c47prop.tga
	{
		map textures/models/vehicles/c47_damage_all/c47prop.tga
		alphafunc GE128
		rgbGen lightingSpherical
	}
}

caska_static_dtruck1
{
	cull none
	qer_editorimage textures/models/VEHICLES/Dtruck/caska_Dtruck1.tga
	{
		map textures/common/reflection1.tga
		rgbGen lightingSpherical
		tcgen environmentmodel
	}
	{
		map textures/models/VEHICLES/Dtruck/caska_Dtruck1.tga
		rgbGen lightingSpherical
		blendfunc gl_one_minus_src_alpha gl_src_alpha 
	}
}

caska_static_dtruckwindow
{
	cull none
	qer_editorimage textures/models/VEHICLES/Dtruck/caska_DTruckWindow.tga
	{
		map textures/common/reflection1.tga
		rgbGen lightingSpherical
		tcgen environmentmodel
	}
	{
		map textures/models/VEHICLES/Dtruck/caska_DTruckWindow.tga
		rgbGen lightingSpherical
		blendfunc gl_one_minus_src_alpha gl_src_alpha 
	}
}

crate010
{
	qer_editorimage textures/models/custom/crate010.tga
	{
		map textures/models/custom/crate010.tga
		rgbGen vertex
	}
}

crypt010
{
	qer_editorimage textures/models/custom/cementery/crypt_c.jpg
	{
		map textures/models/custom/cementery/crypt_c.jpg
		rgbGen vertex
	}
}

cubus_jujeep_main
{
	qer_editorimage textures/milkshape/cubus_Jurassic_Jeep/jeep.tga
	cull none	
	{
		map textures/milkshape/cubus_Jurassic_Jeep/jeep.tga
		rgbGen lightingSpherical
	}
}

cubus_jujeep_wind
{
	qer_editorimage textures/milkshape/cubus_Jurassic_Jeep/glas.tga
	cull none
	{
		map textures/common/reflection1.tga
		rgbGen lightingSpherical
		tcgen environmentmodel
		alphaGen const 0.05
		blendFunc blend
	}
	{
		map textures/milkshape/cubus_Jurassic_Jeep/glas.tga
		rgbGen lightingSpherical
		blendFunc blend
	}
}

cubus_pkmchevy1
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy10
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy2
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy3
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy4
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy5
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy6
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy7
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy8
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

cubus_pkmchevy9
{
cull none
    qer_editorimage	textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
    {
		map textures/milkshape/cubus_pkmchevy/cubus_pkmchevy.tga
     rgbGen lightingSpherical

	}
	
}

dining_t
{
	qer_editorimage textures/renan_models/dining_table.jpg
	{
		map textures/renan_models/dining_table.jpg
		rgbGen vertex
	}
}

flak88_dw
{
	qer_editorimage	textures/models/statweapons/flak88_dw.tga
	{
		map textures/models/statweapons/flak88_dw.tga
		rgbGen lightingSpherical
	}
}

flak88w
{
	qer_editorimage	textures/models/statweapons/flak88w.tga
	{
		map textures/models/statweapons/flak88w.tga
		rgbGen lightingSpherical
	}
}

flatcar_floor
{
	qer_editorimage textures/renan_models/flatcar_floor.jpg
	{
		map textures/renan_models/flatcar_floor.jpg
		rgbGen vertex
	}
}

flatcar_side
{
	qer_editorimage textures/renan_models/flatcar_side.jpg
	{
		map textures/renan_models/flatcar_side.jpg
		rgbGen vertex
	}
}

flowerplants
{
	qer_editorimage textures/renan_models/flowerplants.tga
	cull none
	deformVertexes flap t 24 sin 0 1 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1 0.25 0.3 1 0
	{
		map textures/renan_models/flowerplants.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

fordt_achse
{
	qer_editorimage textures/milkshape/cubus_ford_truck/achse.tga
	cull none
	{
		map textures/milkshape/cubus_ford_truck/achse.tga
		rgbGen lightingSpherical
        
		
	}
}

fordt_boden
{
	qer_editorimage textures/milkshape/cubus_ford_truck/boden.tga
	cull none
	{
		map textures/milkshape/cubus_ford_truck/boden.tga
		rgbGen lightingSpherical
		
        
		
	}
}

fordt_body
{
	qer_editorimage textures/milkshape/cubus_ford_truck/body.tga
	cull none
	{
		map textures/milkshape/cubus_ford_truck/body.tga
		rgbGen lightingSpherical
        
		
	}
}

fordt_dash
{
	qer_editorimage textures/milkshape/cubus_ford_truck/dash.tga
	cull none
	{
		map textures/milkshape/cubus_ford_truck/dash.tga
		rgbGen lightingSpherical
		
        
		
	}
}

fordt_glass
{
	qer_editorimage textures/milkshape/cubus_ford_truck/fenster.tga
	cull none
	{
		map textures/milkshape/cubus_ford_truck/fenster.tga
		rgbGen lightingSpherical
		blendFunc blend
        
		
	}
}

fordt_kabi
{
	qer_editorimage textures/milkshape/cubus_ford_truck/kabi.tga
	cull none
	{
		map textures/milkshape/cubus_ford_truck/kabi.tga
		rgbGen lightingSpherical
		
	}
}

fordt_lenkrad
{
	qer_editorimage textures/milkshape/cubus_ford_truck/lenkrad.tga
	cull none
	{
		map textures/milkshape/cubus_ford_truck/lenkrad.tga
		rgbGen lightingSpherical
		
	}
}

fordt_profilr
{
	nomerge
	cull none
	qer_editorimage textures/milkshape/cubus_ford_truck/profil.tga
	{
		map textures/milkshape/cubus_ford_truck/profil.tga
		rgbGen lightingSpherical
		
		
		tcmod scroll 0 -7
	}
}

fordt_profils
{
	
	cull none
	qer_editorimage textures/milkshape/cubus_ford_truck/profil.tga
	{
		map textures/milkshape/cubus_ford_truck/profil.tga
		rgbGen lightingSpherical
		
		
		
	}
}

fordt_radr
{
	qer_editorimage textures/milkshape/cubus_ford_truck/rad.tga
	nomerge
	cull none
	{
		map textures/milkshape/cubus_ford_truck/rad.tga
		rgbGen lightingSpherical
		tcmod rotate -7 0 15
        
		
	}
}

fordt_rads
{
	qer_editorimage textures/milkshape/cubus_ford_truck/rad.tga
	
	cull none
	{
		map textures/milkshape/cubus_ford_truck/rad.tga
		rgbGen lightingSpherical
		
        
		
	}
}

fordt_sitz
{
	qer_editorimage textures/milkshape/cubus_ford_truck/sitz.tga
	cull none
	{
		map textures/milkshape/cubus_ford_truck/sitz.tga
		rgbGen lightingSpherical
        
		
	}
}

grass1_move
{
       	qer_editorimage textures/HIPout01/broadleaf4.tga
	cull none
	
	
	
	
	deformVertexes flap t 60 sin 0 1.5 0    0.1 1 0
	deformVertexes flap t 60 sin 0 1.5 0.20 0.2 1 0
	{
		
		map textures/HIPout01/broadleaf4.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}	
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
	
}

grass2
{
        qer_editorimage textures/HIPout01/fern02.tga
	cull none
	
	
	{
		map textures/HIPout01/fern02.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
}

grass2_move
{
        qer_editorimage textures/HIPout01/fern02.tga
	cull none
	
	
	deformVertexes flap t 60 sin 0 1.5 0    0.1 1 0
	deformVertexes flap t 60 sin 0 1.5 0.20 0.2 1 0
	{
		map textures/HIPout01/fern02.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
}

grass3_move
{
        qer_editorimage textures/HIPout01/fern01.tga
	cull none
	
	
	deformVertexes flap t 60 sin 0 1.5 0    0.1 1 0
	deformVertexes flap t 60 sin 0 1.5 0.20 0.2 1 0
	{
		map textures/HIPout01/fern01.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
}

grass4
{
    	qer_editorimage textures/HIPout01/broadleaf3.tga
	cull none
	nomipmaps
	nopicmip
	{
		map textures/HIPout01/broadleaf3.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
}

grass4_move
{
    	qer_editorimage textures/HIPout01/broadleaf3.tga
	cull none
	nomipmaps
	nopicmip
	deformVertexes flap t 60 sin 0 1.5 0    0.1 1 0
	deformVertexes flap t 60 sin 0 1.5 0.20 0.2 1 0
	{
		map textures/HIPout01/broadleaf3.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
}

hedgerow
{
	qer_editorimage textures/renan_models/hedgerow02.tga
	cull none
	deformVertexes flap t 24 sin 0 1 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1 0.25 0.3 1 0
	{
		map textures/renan_models/hedgerow02.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

hippalm1base
{
	qer_editorimage textures/HIPout01/palmbark1.tga
	nomipmaps
	nopicmip
	cull none
	{
		map textures/HIPout01/palmbark1.tga
		depthWrite
		rgbGen vertex		
	}
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
}

hippalm1center
{
       	qer_editorimage textures/HIPout01/palm05.tga
	cull none
	nomipmaps
	nopicmip
	{
		map textures/HIPout01/palm05.tga
		depthWrite
		rgbGen vertex
		alphaFunc GE128
		nextbundle
		map $lightmap
	}
}

hitpalm2_spread
{
       	qer_editorimage textures/HIPout01/palmbranch1.tga
	cull none
	
	
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		map textures/HIPout01/palmbranch1.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}	
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
	
}

hitpalm2_spread1
{
       	qer_editorimage textures/HIPout01/palmbranch1.tga
	cull none
	{
		map textures/HIPout01/palmbranch1.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}	
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
	
}

hitpbush1bwind
{
    	qer_editorimage textures/HIPout02/baum2.tga
	cull none
	nomipmaps
	nopicmip
	deformVertexes flap t 60 sin 0 1.5 0    0.1 1 0
	deformVertexes flap t 55 sin 0 2.0 0.20 0.2 1 0
	{
		map textures/HIPout02/baum2.tga
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
}

hitpbush2_move
{
       	qer_editorimage textures/HIPout02/bush2.tga
	cull none
	
	
	
	
	deformVertexes flap t 60 sin 0 1.5 0    0.1 1 0
	deformVertexes flap t 60 sin 0 1.5 0.20 0.2 1 0
	{
		map textures/HIPout02/bush2.tga
		
		alphaFunc GE128
		depthWrite
		rgbGen vertex
		
		
	}	
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
	
}

hitppalm1_move
{
	qer_editorimage textures/HIPout01/palm05.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/HIPout01/palm05.tga
		depthWrite
		alphaFunc GE128
		
		rgbGen lightingGrid
	}
}

hitppalm2_base
{
	qer_editorimage textures/hitpmodels/hitptree02.tga
	cull none
	{
		map textures/hitpmodels/hitptree02.tga
		rgbGen vertex
		depthWrite
	}
	{
		map $lightmap
		blendFunc GL_DST_COLOR GL_ZERO
		rgbGen vertex
		depthFunc equal
	}
}

lamp5
{
	qer_editorimage textures/renan_models/lampost.tga
	cull none
	{
		map textures/renan_models/lampost.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

panzer_iv_backwheel_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/backwheel_eudw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv_d/backwheel_eudw.tga
		rgbGen lightingSpherical
		alphafunc ge128
		depthwrite

	}
}

panzer_iv_backwheel_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/backwheel_euw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv/backwheel_euw.tga
		rgbGen lightingSpherical
		alphafunc ge128
		depthwrite
	}
}

panzer_iv_backwheelaxel_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/backwheelaxelw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv/backwheelaxelw.tga
		rgbGen lightingSpherical
 	}
}

panzer_iv_backwheelaxel_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/backwheelaxelw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv/backwheelaxelw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_backwheelband_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/backwheelband_eudw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv_d/backwheelband_eudw.tga
		rgbGen lightingSpherical
		alphafunc ge128
	}
}

panzer_iv_backwheelband_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/backwheelband_euw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv/backwheelband_euw.tga
		rgbGen lightingSpherical
		alphafunc ge128
	}
}

panzer_iv_boxes_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/boxes_eudw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv_d/boxes_eudw.tga
		rgbGen lightingSpherical
		alphafunc ge128
		depthwrite
	}
}

panzer_iv_boxes_euw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/boxes_euw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv/boxes_euw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_frontwheel_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/frontwheel_eudw.tga
	{
		map textures/models/vehicles/panzer_iv_d/frontwheel_eudw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_frontwheel_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/frontwheel_euw.tga
	{
		map textures/models/vehicles/panzer_iv/frontwheel_euw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_frontwheelband_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/frontwheelband_eudw.tga
	{
		map textures/models/vehicles/panzer_iv_d/frontwheelband_eudw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_frontwheelband_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/frontwheelband_euw.tga
	{
		map textures/models/vehicles/panzer_iv/frontwheelband_euw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_smallwheel_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/smallwheel_eudw.tga
	{
		map textures/models/vehicles/panzer_iv_d/smallwheel_eudw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_smallwheel_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/smallwheel_euw.tga
	{
		map textures/models/vehicles/panzer_iv/smallwheel_euw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_smallwheelband_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/frontwheelband_eudw.tga
	{
		map textures/models/vehicles/panzer_iv_d/frontwheelband_eudw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_smallwheelband_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/smallwheelbandw.tga
	{
		map textures/models/vehicles/panzer_iv/smallwheelbandw.tga
		rgbGen lightingSpherical
        }
}

panzer_iv_t_eud2w
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/undercarriage_eudw.tga
	cull none
	{
		map textures/models/vehicles/panzer_iv_d/undercarriage_eudw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_tread_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/tread_eudw.tga
	{
		map textures/models/vehicles/panzer_iv_d/tread_eudw.tga
		rgbGen lightingSpherical
        }
}

panzer_iv_tread_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/tread_euw.tga
	{
		map textures/models/vehicles/panzer_iv/tread_euw.tga
		rgbGen lightingSpherical

        }
}

panzer_iv_turret_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/turret_eudw.tga
	{
		map textures/models/vehicles/panzer_iv_d/turret_eudw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_turret_euw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/turret_euw.tga
	{
		map textures/models/vehicles/panzer_iv/turret_euw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_undercarriage_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/undercarriage_eudw.tga
	{
		map textures/models/vehicles/panzer_iv_d/undercarriage_eudw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_undercarriage_euw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/undercarriage_euw.tga
	{
		map textures/models/vehicles/panzer_iv/undercarriage_euw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_verysmallwheel_eudw
{
	qer_editorimage	textures/models/vehicles/panzer_iv_d/verysmallwheel_eudw.tga
	{
		map textures/models/vehicles/panzer_iv_d/verysmallwheel_eudw.tga
		rgbGen lightingSpherical
	}
}

panzer_iv_verysmallwheel_eunw
{
	qer_editorimage	textures/models/vehicles/panzer_iv/verysmallwheel_euw.tga
	{
		map textures/models/vehicles/panzer_iv/verysmallwheel_euw.tga
		rgbGen lightingSpherical
	}
}

plants_b
{
	qer_editorimage textures/renan_models/plants_b.tga
	cull none
	deformVertexes flap t 24 sin 0 1 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1 0.25 0.3 1 0
	{
		map textures/renan_models/plants_b.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

rail_wheelface
{
	qer_editorimage textures/renan_models/rail_wheelface.tga
	{
		map textures/renan_models/rail_wheelface.tga
		rgbGen vertex
	}
}

railcar_axle
{
	qer_editorimage textures/renan_models/railcar_axle.jpg
	{
		map textures/renan_models/railcar_axle.jpg
		rgbGen vertex
	}
}

railcar_beam1
{
	qer_editorimage textures/renan_models/railcar_beam1.jpg
	{
		map textures/renan_models/railcar_beam1.jpg
		rgbGen vertex
	}
}

railcar_roof
{
	qer_editorimage textures/renan_models/railcar_roof.jpg
	{
		map textures/renan_models/railcar_roof.jpg
		rgbGen vertex
	}
}

railcar_spring
{
	qer_editorimage textures/renan_models/railcar_spring.jpg
	{
		map textures/renan_models/railcar_spring.jpg
		rgbGen vertex
	}
}

railcar_trim
{
	qer_editorimage textures/renan_models/railcar_trim.jpg
	{
		map textures/renan_models/railcar_trim.jpg
		rgbGen vertex
	}
}

refri
{
	qer_editorimage textures/renan_models/refrigerator.jpg
	{
		map textures/renan_models/refrigerator.jpg
		rgbGen vertex
	}
}

sinkb
{
	qer_editorimage textures/renan_models/sinkb.jpg
	{
		map textures/renan_models/sinkb.jpg
		rgbGen vertex
	}
}

socket5
{
	qer_editorimage textures/renan_models/socket.jpg
	{
		map textures/renan_models/socket.jpg
		rgbGen vertex
	}
}

static_bush2a_1w
{
	qer_editorimage textures/models/natural/bush2a_1w.tga
	cull none
	{
		clampmap textures/models/natural/bush2a_1w.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

static_bush3_1_autumn
{
	qer_editorimage textures/models/natural/bush3_1_autumn.tga
	cull none
	deformVertexes flap t 24 sin 0 1 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1 0.25 0.3 1 0
	{
		map textures/models/natural/bush3_1_autumn.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

static_bush3_1winter
{
	qer_editorimage textures/models/natural/bush3_1winter.tga
	cull none
	deformVertexes flap t 24 sin 0 1 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1 0.25 0.3 1 0
	{
		map textures/models/natural/bush3_1winter.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

static_bush3_2_autumn
{
	qer_editorimage textures/models/natural/bush3_2_autumn.tga
	cull none
	deformVertexes wave 24 sin 0 0.75 0    0.2
	deformVertexes wave 24 sin 0 0.75 0.25 0.3
	{
		clampmap textures/models/natural/bush3_2_autumn.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

static_bush3_2winter
{
	qer_editorimage textures/models/natural/bush3_2winter.tga
	cull none
	deformVertexes wave 24 sin 0 0.75 0    0.2
	deformVertexes wave 24 sin 0 0.75 0.25 0.3
	{
		clampmap textures/models/natural/bush3_2winter.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

static_bush3_3_autumn
{
	qer_editorimage textures/models/natural/bush3_3_autumn.tga
	cull none
	deformVertexes flap t 24 sin 0 1 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1 0.25 0.3 1 0
	{
		clampmap textures/models/natural/bush3_3_autumn.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

static_bush3_3winter
{
	qer_editorimage textures/models/natural/bush3_3winter.tga
	cull none
	deformVertexes flap t 24 sin 0 1 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1 0.25 0.3 1 0
	{
		clampmap textures/models/natural/bush3_3winter.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

static_bush4_1w
{
	qer_editorimage textures/models/natural/bush4_1w.tga
	{
		map textures/models/natural/bush4_1w.tga
		rgbGen vertex
	}
}

static_bush4_2w
{
	qer_editorimage textures/models/natural/bush4_2w.tga
	cull none
	deformVertexes wave 24 sin 0 0.5 0    0.2
	deformVertexes wave 24 sin 0 0.5 0.25 0.3
	{
		clampmap textures/models/natural/bush4_2w.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

static_fan_movable
{
	qer_editorimage textures/models/items/fan.tga
	cull none
	{
		map textures/models/items/fan.tga
		rgbGen lightingSpherical
		alphaFunc GE128
		depthWrite
	}
}

static_hedgehog_w
{
	qer_editorimage textures/models/items/hedgehog_w.tga
	cull none
	{
		map textures/models/items/hedgehog_w.tga
		rgbGen lightingSpherical
	}
}

static_lrock2_omaha
{
	qer_editorimage textures/mohcommon/rckfcset1_1.jpg
	{
		map textures/mohcommon/rckfcset1_1.jpg
		rgbGen vertex
	}
}

static_shermantank_deadw
{
	qer_editorimage textures/models/vehicles/shermantank/shermandeadw.tga
	{
		map textures/models/vehicles/shermantank/shermandeadw.tga
		rgbGen lightingSpherical
		alphaFunc ge128
		depthWrite
	}
}

static_shermantankw
{
	qer_editorimage textures/models/vehicles/shermantank/shermantankw.tga
	{
		map textures/models/vehicles/shermantank/shermantankw.tga
		rgbGen lightingSpherical
		alphaFunc ge128
		depthWrite
	}
}

static_shermantredzw
{
	qer_editorimage textures/models/vehicles/shermantank/shermantredzw.tga
	cull none
	{
		map textures/models/vehicles/shermantank/shermantredzw.tga
		rgbGen lightingSpherical
		alphaFunc ge128
		depthWrite
	}
}

static_tree1_1
{
	qer_editorimage textures/models/natural/tree1_1.tga
	{
		map textures/models/natural/tree1_1.tga
		alphaGen distFade 2304 0
		rgbgen static
	}
}

static_tree1_1winter
{
	qer_editorimage textures/models/natural/tree1_1winter.tga
	{
		map textures/models/natural/tree1_1winter.tga
		alphaGen distFade 2304 0
		rgbgen vertex
	}
}

static_tree1_2ttc
{
	qer_editorimage textures/models/natural/tree1_2ttc.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree1_2ttc.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 512 256
		rgbgen vertex
	}
}

static_tree1_2winter
{
	qer_editorimage textures/models/natural/tree1_2winter.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree1_2winter.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 512 256
		rgbgen vertex
	}
}

static_tree1_3ttc
{
	qer_editorimage textures/models/natural/tree1_3ttc.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree1_3ttc.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 512
		rgbgen vertex
	}
}

static_tree1_3winter
{
	qer_editorimage textures/models/natural/tree1_3winter.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree1_3winter.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 512
		rgbgen vertex
	}
}

static_tree1_4ttc
{
	qer_editorimage textures/models/natural/tree1_4ttc.tga
	nomipmaps
	
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree1_4ttc.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbgen vertex
	}
}

static_tree1_4winter
{
	qer_editorimage textures/models/natural/tree1_4winter.tga
	nomipmaps
	
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree1_4winter.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbgen vertex
	}
}

static_tree1_5ttc
{
	qer_editorimage textures/models/natural/tree1_5ttc.tga
	nomipmaps
	cull none



	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0




	{
		clampmap textures/models/natural/tree1_5ttc.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 256
		rgbgen vertex
	}
}

static_tree1_5winter
{
	qer_editorimage textures/models/natural/tree1_5winter.tga
	nomipmaps
	cull none



	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0




	{
		clampmap textures/models/natural/tree1_5winter.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 256
		rgbgen vertex
	}
}

static_tree1spritettc
{
	qer_editorimage textures/models/natural/tree1spritettc.tga
	qer_trans 0
	nomipmaps
	deformVertexes autoSprite2
	cull none
	{
		clampmap textures/models/natural/tree1spritettc.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 1216 512
		rgbgen vertex
	}
}

static_tree1spritewinter
{
	qer_editorimage textures/models/natural/tree1spritewinter.tga
	qer_trans 0
	nomipmaps
	deformVertexes autoSprite2
	cull none
	{
		clampmap textures/models/natural/tree1spritewinter.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 1216 512
		rgbgen vertex
	}
}

static_tree2a_1
{
	qer_editorimage textures/models/natural/tree2a_1.tga
	{
		map textures/models/natural/tree2a_1.tga
		rgbGen vertex
		alphaGen distFade 1000 600
	}
}

static_tree2a_2_autumn
{
	qer_editorimage textures/models/natural/tree2a_2_autumn.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree2a_2_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1200 500
		rgbGen vertex
	}
}

static_tree2a_3_autumn
{
	qer_editorimage textures/models/natural/tree2a_3_autumn.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree2a_3_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 2100 1500
		rgbGen vertex
	}
}

static_tree2a_4_autumn
{
	qer_editorimage textures/models/natural/tree2a_4_autumn.tga
	nomipmaps
	cull none
	deformVertexes wave 24 sin 0 1.5 0    0.2 
	deformVertexes wave 24 sin 0 1.5 0.25 0.3 
	{
		clampmap textures/models/natural/tree2a_4_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 512 512
		rgbGen vertex
	}
}

static_tree2asprite_autumn
{
	qer_editorimage textures/models/natural/tree2asprite_autumn.tga
	qer_trans 0
	nomipmaps
	deformVertexes autoSprite2
	cull none
	{
		clampmap textures/models/natural/tree2asprite_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 900 500
		rgbGen vertex
	}
}

static_tree4_1
{
	qer_editorimage textures/models/natural/tree4_1.tga
	{
		map textures/models/natural/tree4_1.tga
		rgbGen vertex
		alphaGen distFade 2000 600
	}
}

static_tree4_1winter
{
	qer_editorimage textures/models/natural/tree4_1winter.tga
	{
		map textures/models/natural/tree4_1winter.tga
		rgbGen vertex
		alphaGen distFade 2000 600
	}
}

static_tree4_2_autumn
{
	qer_editorimage textures/models/natural/tree4_2_autumn.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree4_2_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 2000 1500
		rgbGen vertex
	}
}

static_tree4_2winter
{
	qer_editorimage textures/models/natural/tree4_2winter.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree4_2winter.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 2000 1500
		rgbGen vertex
	}
}

static_tree4_3_autumn
{
	qer_editorimage textures/models/natural/tree4_3_autumn.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree4_3_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1400 1400
		rgbGen vertex
	}
}

static_tree4_3winter
{
	qer_editorimage textures/models/natural/tree4_3winter.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree4_3winter.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1400 1400
		rgbGen vertex
	}
}

static_tree4_4_autumn
{
	qer_editorimage textures/models/natural/tree4radial_autumn.tga
	nomipmaps
	cull none
	deformVertexes wave 24 sin 0 0.5 0    0.2
	deformVertexes wave 24 sin 0 0.5 0.25 0.3
	{
		clampmap textures/models/natural/tree4radial_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbGen vertex
	}
}

static_tree4_4winter
{
	qer_editorimage textures/models/natural/tree4radialwinter.tga
	nomipmaps
	cull none
	deformVertexes wave 24 sin 0 0.5 0    0.2
	deformVertexes wave 24 sin 0 0.5 0.25 0.3
	{
		clampmap textures/models/natural/tree4radialwinter.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbGen vertex
	}
}

static_tree4_6_autumn
{
	qer_editorimage textures/models/natural/tree4_3_autumn.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree4_3_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1000 1000
		rgbGen vertex
	}
}

static_tree4_7_autumn
{
	qer_editorimage textures/models/natural/tree4radial_autumn.tga
	nomipmaps
   
	deformVertexes flap t 24 sin 0 1.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/tree4radial_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 300 300
		rgbGen vertex
	}
}

static_tree4sprite_autumn
{
	qer_editorimage textures/models/natural/tree4sprite_autumn.tga
	qer_trans 0
	nomipmaps
	deformVertexes autoSprite2
	cull none
	{
		clampmap textures/models/natural/tree4sprite_autumn.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 900 900
		rgbGen vertex
	}
}

static_tree5s_1_dtr
{
	qer_editorimage textures/models/natural/tree5s_1.tga
	{
		map textures/models/natural/tree5s_1.tga
		rgbGen static
	alphaGen distFade 900 0
	}
}

static_tree5s_2_dtr
{
	qer_editorimage textures/models/natural/tree5s_2.tga
		nomipmaps
	cull none

	{
		clampmap textures/models/natural/tree5s_2.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1200 500
		rgbGen static
	}
}

static_tree5s_3_dtr
{
	qer_editorimage textures/models/natural/tree5s_3.tga
	nomipmaps
	cull none

	deformVertexes flap t 24 sin 2 3 0 .25 1 0
	{
		clampmap textures/models/natural/tree5s_3.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 2100 1500
		rgbGen static
	}
}

static_tree5sb_1_dtr
{
	qer_editorimage textures/models/natural/tree5s_1.tga
	{
		map textures/models/natural/tree5s_1.tga
		rgbGen static
		alphaGen distFade 900 0
	}
}

static_tree5sb_2_dtr
{
	qer_editorimage textures/models/natural/tree5s_2.tga
		nomipmaps
	cull none

	{
		clampmap textures/models/natural/tree5s_2.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1500 800
		rgbGen static
	}
}

static_tree5sb_3_dtr
{
	qer_editorimage textures/models/natural/tree5s_3.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 2 3 0 .25 1 0
	{
		clampmap textures/models/natural/tree5s_3.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1800 900
		rgbGen static
	}
}

static_tree5ssprite_dtr
{
	qer_editorimage textures/models/natural/tree5ssprite.tga
	qer_trans 0
	nomipmaps
	deformVertexes autoSprite2
	cull none
	{
		clampmap textures/models/natural/tree5ssprite.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 900 500
		rgbGen static
	}
}

static_tree5sspriteb_dtr
{
	qer_editorimage textures/models/natural/tree5sspriteb.tga
	qer_trans 0
	nomipmaps
	deformVertexes autoSprite2
	cull none
	{
		clampmap textures/models/natural/tree5sspriteb.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 900 500
		rgbGen static
	}
}

stone_bench
{
	qer_editorimage textures/models/custom/stone_bench.tga
	{
		map textures/models/custom/stone_bench.tga
		rgbGen vertex
	}
}

stove5
{
	qer_editorimage textures/renan_models/stove_old.jpg
	{
		map textures/renan_models/stove_old.jpg
		rgbGen vertex
	}
}

streetlamp
{
	qer_editorimage textures/models/custom/streetlamp.tga
	{
		map textures/models/custom/streetlamp.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 512
		rgbGen lightingGrid
	}
}

tombstone10
{
	qer_editorimage textures/models/custom/cementery/rock@tombstone1.jpg
	{
		map textures/models/custom/cementery/rock@tombstone1.jpg
		rgbGen vertex
	}
}

tombstone20
{
	qer_editorimage textures/models/custom/cementery/rock@tombstone2.tga
	{
		map textures/models/custom/cementery/rock@tombstone2.tga
		rgbGen vertex
	}
}

tombstone30
{
	qer_editorimage textures/models/custom/cementery/rock@tombstone3.tga
	{
		map textures/models/custom/cementery/rock@tombstone3.tga
		rgbGen vertex
	}
}

tombstone40
{
	qer_editorimage textures/models/custom/cementery/rock@tombstone4.jpg
	{
		map textures/models/custom/cementery/rock@tombstone4.jpg
		rgbGen vertex
	}
}

tombstone60
{
	qer_editorimage textures/models/custom/cementery/rock@tombstone6.jpg
	{
		map textures/models/custom/cementery/rock@tombstone6.jpg
		rgbGen vertex
	}
}

tombstone70
{
	qer_editorimage textures/models/custom/cementery/rock@tombstone7.jpg
	{
		map textures/models/custom/cementery/rock@tombstone7.jpg
		rgbGen vertex
	}
}

tombstone80
{
	qer_editorimage textures/models/custom/cementery/rock@tombstone8.jpg
	{
		map textures/models/custom/cementery/rock@tombstone8.jpg
		rgbGen vertex
	}
}

tombstone90
{
	qer_editorimage textures/models/custom/cementery/rock@tombstone9.jpg
	{
		map textures/models/custom/cementery/rock@tombstone9.jpg
		rgbGen vertex
	}
}

tree_desertbushy
{
	qer_editorimage textures/renan_models/tree_desertbushy.tga
	cull none
	deformVertexes flap t 24 sin 0 1 0    0.2 1 0
	deformVertexes flap t 24 sin 0 1 0.25 0.3 1 0
	{
		map textures/renan_models/tree_desertbushy.tga
		depthWrite
		alphafunc GE128
		rgbGen vertex
	}
}

turret_dtl_axis
{
	qer_editorimage textures/models/vehicles/ktigertank/axis_details.tga
	{
		map textures/models/vehicles/ktigertank/axis_details.tga
		rgbGen lightingGrid
	}
}

turretbarrel_axis
{
	qer_editorimage textures/models/vehicles/ktigertank/axis_turretbarrel.tga
	{
		map textures/models/vehicles/ktigertank/axis_turretbarrel.tga
		rgbGen lightingGrid
	}
}

turretbase_axis
{
	qer_editorimage textures/models/vehicles/ktigertank/axis_turretbase.tga
	{
		map textures/models/vehicles/ktigertank/axis_turretbase.tga
		rgbGen lightingGrid
	}
}

turretneck_axis
{
	qer_editorimage textures/models/vehicles/ktigertank/axis_turretneck.tga
	{
		map textures/models/vehicles/ktigertank/axis_turretneck.tga
		rgbGen lightingGrid
	}
}

turretshaft_axis
{
	qer_editorimage textures/models/vehicles/ktigertank/axis_turretshaft.tga
	{
		map textures/models/vehicles/ktigertank/axis_turretshaft.tga
		rgbGen lightingGrid
	}
}

w_barrel
{
	qer_editorimage textures/renan_models/woodbarrel_waw.jpg
	{
		map textures/renan_models/woodbarrel_waw.jpg
		rgbGen vertex
	}
}

w_table
{
	qer_editorimage textures/renan_models/w_table.jpg
	{
		map textures/renan_models/w_table.jpg
		rgbGen vertex
	}
}

water_tower
{
	qer_editorimage textures/renan_models/water_tower.jpg
	{
		map textures/renan_models/water_tower.jpg
		rgbGen vertex
	}
}

waw_bathtub1
{
	qer_editorimage textures/renan_models/bathub5.jpg
	{
		map textures/renan_models/bathub5.jpg
		rgbGen vertex
	}
}

waw_bed
{
	qer_editorimage textures/renan_models/berlin_bed.jpg
	{
		map textures/renan_models/berlin_bed.jpg
		rgbGen vertex
	}
}

wbarrel
{
	qer_editorimage textures/renan_models/w_barrel_s.jpg
	{
		map textures/renan_models/w_barrel_s.jpg
		rgbGen vertex
	}
}

wood_champagne_crate
{
	qer_editorimage textures/models/custom/wood_champagne_crate.tga
	{
		map textures/models/custom/wood_champagne_crate.tga
		rgbGen vertex
	}
}

wood_crate
{
	qer_editorimage textures/models/custom/wood_crate.tga
	{
		map textures/models/custom/wood_crate.tga
		rgbGen vertex
	}
}

wood_subway
{
	qer_editorimage textures/renan_models/wood_subway.jpg
	{
		map textures/renan_models/wood_subway.jpg
		rgbGen vertex
	}
}

wooden_barrel
{
	qer_editorimage textures/models/custom/wooden_barrel.tga
	{
		map textures/models/custom/wooden_barrel.tga
		rgbGen vertex
	}
}

woodstack
{
	qer_editorimage textures/models/custom/woodstack_all.tga
	{
		map textures/models/custom/woodstack_all.tga
		rgbGen vertex
	}
}

