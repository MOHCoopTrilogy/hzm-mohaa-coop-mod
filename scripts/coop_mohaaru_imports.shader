// coop_mohaaru_imports.shader
// Auto-generated for HZM coop build-mode: shader defs for the imported "MOHAA Reunited"
// (MOHAARU) placeable objects (build-mode catalog cats 37/38 MOHAARU COVER / MOHAARU SCENE).
// Each block was lifted verbatim from the source MOHAARU map-pack shader scripts; only the
// blocks these models reference are included, so nothing here overrides a vanilla or
// existing-mod shader (verified 0 name collisions, incl. vs coop_1936_imports.shader).
// Source: community MOHAARU map packs. See _research/buildmode_objects_customaps.md.

bakerSign_bakersSign
{
      qer_editorimage textures/milkshape/bakerSign/bakersSign.jpg
      cull none
      {
            map textures/milkshape/bakerSign/bakersSign.jpg
            rgbGen lightingSpherical
      }
}

Bottle_bottle
{
      qer_editorimage textures/milkshape/Bottle/bottle.tga
      cull none
      {
            map textures/milkshape/Bottle/bottle.tga
            rgbGen lightingSpherical
      }
}

bottle_broken_bottle_broken
{
      qer_editorimage textures/milkshape/bottle_broken/bottle_broken.tga
      cull none
      {
            map textures/milkshape/bottle_broken/bottle_broken.tga
            rgbGen lightingSpherical
      }
}

bouteille_bouteille
{
      qer_editorimage textures/papys/bouteille/bouteille.jpg
      cull none
      {
            map textures/papys/bouteille/bouteille.jpg
            rgbGen lightingSpherical
      }
}

bouteille_etiquette
{
      qer_editorimage textures/papys/bouteille/etiquette.jpg
      cull none
      {
            map textures/papys/bouteille/etiquette.jpg
            rgbGen lightingSpherical
      }
}

bread_bread
{
      qer_editorimage textures/milkshape/bread/bread.jpg
      cull none
      {
            map textures/milkshape/bread/bread.jpg
            rgbGen lightingSpherical
      }
}

butcherSign_butchersSign
{
      qer_editorimage textures/milkshape/butcherSign/butchersSign.jpg
      cull none
      {
            map textures/milkshape/butcherSign/butchersSign.jpg
            rgbGen lightingSpherical
      }
}

chair_chair
{
      qer_editorimage textures/milkshape/chair/chair.tga
      cull none
      {
            map textures/milkshape/chair/chair.tga
            rgbGen lightingSpherical
      }
}

floristSign_floristSign
{
      qer_editorimage textures/milkshape/floristSign/floristSign.jpg
      cull none
      {
            map textures/milkshape/floristSign/floristSign.jpg
            rgbGen lightingSpherical
      }
}

grass1
{
       	qer_editorimage textures/HIPout01/broadleaf4.tga
	cull none
	
	
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

grass3
{
        qer_editorimage textures/HIPout01/fern01.tga
	cull none
	
	
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

grass5_move
{
    	qer_editorimage textures/HIPout01/grass06.tga
	cull none
	nomipmaps
	nopicmip
	deformVertexes flap t 60 sin 0 1.5 0    0.1 1 0
	deformVertexes flap t 55 sin 0 2.0 0.20 0.2 1 0
	{
		map textures/HIPout01/grass06.tga
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

hitpbush1b
{
    	qer_editorimage textures/HIPout02/baum2.tga
	cull none
	nomipmaps
	nopicmip
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

hitpbush2
{
       	qer_editorimage textures/HIPout02/bush2.tga
	cull none
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

kubelwagen_arriere
{
      qer_editorimage textures/milkshape/kubelwagen/arriere.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/arriere.jpg
            rgbGen lightingSpherical
      }
}

kubelwagen_cote
{
      qer_editorimage textures/milkshape/kubelwagen/cote.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/cote.jpg
            rgbGen lightingSpherical
      }
}

kubelwagen_dessus
{
      qer_editorimage textures/milkshape/kubelwagen/dessus.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/dessus.jpg
            rgbGen lightingSpherical
      }
}

kubelwagen_fond
{
      qer_editorimage textures/milkshape/kubelwagen/fond.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/fond.jpg
            rgbGen lightingSpherical
      }
}

kubelwagen_kubel1
{
	qer_editorimage textures/milkshape/kubelwagen/kubel1.tga
	cull none
	{
		map textures/common/reflection1.tga
		rgbGen lightingSpherical
		tcgen environmentmodel
		alphaGen const 0.05
		blendFunc blend
	}
	{
		map textures/milkshape/kubelwagen/kubel1.tga
		rgbGen lightingSpherical
		blendFunc blend
	}
}

kubelwagen_phare
{
      qer_editorimage textures/milkshape/kubelwagen/phare.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/phare.jpg
            rgbGen lightingSpherical
      }
}

kubelwagen_roues
{
      qer_editorimage textures/milkshape/kubelwagen/roues.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/roues.jpg
            rgbGen lightingSpherical
      }
}

kubelwagen_sieges
{
      qer_editorimage textures/milkshape/kubelwagen/sieges.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/sieges.jpg
            rgbGen lightingSpherical
      }
}

kubelwagen_tableaubord
{
      qer_editorimage textures/milkshape/kubelwagen/tableaubord.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/tableaubord.jpg
            rgbGen lightingSpherical
      }
}

kubelwagen_tranchesroues
{
      qer_editorimage textures/milkshape/kubelwagen/tranchesroues.jpg
      cull none
      {
            map textures/milkshape/kubelwagen/tranchesroues.jpg
            rgbGen lightingSpherical
      }
}

loaf_loaf
{
      qer_editorimage textures/milkshape/loaf/loaf.jpg
      cull none
      {
            map textures/milkshape/loaf/loaf.jpg
            rgbGen lightingSpherical
      }
}

meatknife_meatcleaver
{
      qer_editorimage textures/milkshape/meatknife/meatcleaver.jpg
      cull none
      {
            map textures/milkshape/meatknife/meatcleaver.jpg
            rgbGen lightingSpherical
      }
}

pak40_canon
{
      qer_editorimage textures/milkshape/pak40/canon.jpg
      cull none
      {
            map textures/milkshape/pak40/canon.jpg
            rgbGen lightingSpherical
      }
}

pak40_pak40-1
{
      qer_editorimage textures/milkshape/pak40/pak40-1.jpg
      cull none
      {
            map textures/milkshape/pak40/pak40-1.jpg
            rgbGen lightingSpherical
      }
}

pak40_pak40-2
{
      qer_editorimage textures/milkshape/pak40/pak40-2.jpg
      cull none
      {
            map textures/milkshape/pak40/pak40-2.jpg
            rgbGen lightingSpherical
      }
}

pak40_pak40-3
{
      qer_editorimage textures/milkshape/pak40/pak40-3.jpg
      cull none
      {
            map textures/milkshape/pak40/pak40-3.jpg
            rgbGen lightingSpherical
      }
}

pak40_pak40-4
{
      qer_editorimage textures/milkshape/pak40/pak40-4.jpg
      cull none
      {
            map textures/milkshape/pak40/pak40-4.jpg
            rgbGen lightingSpherical
      }
}

pak40_pak40-5
{
      qer_editorimage textures/milkshape/pak40/pak40-5.jpg
      cull none
      {
            map textures/milkshape/pak40/pak40-5.jpg
            rgbGen lightingSpherical
      }
}

pak40_pak40-6
{
      qer_editorimage textures/milkshape/pak40/pak40-6.jpg
      cull none
      {
            map textures/milkshape/pak40/pak40-6.jpg
            rgbGen lightingSpherical
      }
}

pak40_pieds
{
      qer_editorimage textures/milkshape/pak40/pieds.jpg
      cull none
      {
            map textures/milkshape/pak40/pieds.jpg
            rgbGen lightingSpherical
      }
}

pak40_plaque
{
      qer_editorimage textures/milkshape/pak40/plaque.jpg
      cull none
      {
            map textures/milkshape/pak40/plaque.jpg
            rgbGen lightingSpherical
      }
}

sausages_sausage
{
      qer_editorimage textures/milkshape/sausages/sausage.jpg
      cull none
      {
            map textures/milkshape/sausages/sausage.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_233canon
{
      qer_editorimage textures/milkshape/sdkfz-234-1/233canon.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/233canon.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_233cote
{
      qer_editorimage textures/milkshape/sdkfz-234-1/233cote.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/233cote.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_233dessus
{
      qer_editorimage textures/milkshape/sdkfz-234-1/233dessus.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/233dessus.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_233face
{
      qer_editorimage textures/milkshape/sdkfz-234-1/233face.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/233face.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_233roues
{
      qer_editorimage textures/milkshape/sdkfz-234-1/233roues.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/233roues.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_culasse234
{
      qer_editorimage textures/milkshape/sdkfz-234-1/culasse234.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/culasse234.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_grillecote
{
      qer_editorimage textures/milkshape/sdkfz-234-1/grillecote.tga
      cull none
      {
            map textures/milkshape/sdkfz-234-1/grillecote.tga
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_grilledessus
{
      qer_editorimage textures/milkshape/sdkfz-234-1/grilledessus.tga
      cull none
      {
            map textures/milkshape/sdkfz-234-1/grilledessus.tga
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_jagd8
{
      qer_editorimage textures/milkshape/sdkfz-234-1/jagd8.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/jagd8.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_tourelle234cote
{
      qer_editorimage textures/milkshape/sdkfz-234-1/tourelle234cote.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/tourelle234cote.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-1_tourelle234face
{
      qer_editorimage textures/milkshape/sdkfz-234-1/tourelle234face.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-1/tourelle234face.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_canon
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/canon.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/canon.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_cote
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/cote.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/cote.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_cotetourelle
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/cotetourelle.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/cotetourelle.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_cottourelle
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/cottourelle.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/cottourelle.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_dessus
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/dessus.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/dessus.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_dessustourelle
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/dessustourelle.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/dessustourelle.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_facedessous
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/facedessous.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/facedessous.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_jagd8
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/jagd8.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/jagd8.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-2-puma_roues
{
      qer_editorimage textures/milkshape/sdkfz-234-2-puma/roues.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-2-puma/roues.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_canon
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/canon.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/canon.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_cote
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/cote.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/cote.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_cotetourelle
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/cotetourelle.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/cotetourelle.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_cottourelle
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/cottourelle.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/cottourelle.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_dessus
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/dessus.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/dessus.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_dessustourelle
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/dessustourelle.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/dessustourelle.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_facedessous
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/facedessous.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/facedessous.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_jagd8
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/jagd8.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/jagd8.jpg
            rgbGen lightingSpherical
      }
}

sdkfz-234-3-puma_roues
{
      qer_editorimage textures/milkshape/sdkfz-234-3-puma/roues.jpg
      cull none
      {
            map textures/milkshape/sdkfz-234-3-puma/roues.jpg
            rgbGen lightingSpherical
      }
}

static_common_fall_orange1_1	
{
	qer_editorimage textures/models/natural/common_fall_orange1_1.tga
	{
		map textures/models/natural/common_fall_orange1_1.tga
		alphaGen distFade 2304 0
		rgbgen vertex
	}
}

static_common_fall_orange1_2 
{
	qer_editorimage textures/models/natural/common_fall_orange1_2.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/common_fall_orange1_2.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 512 256
		rgbgen vertex
	}
}

static_common_fall_orange1_3 
{
	qer_editorimage textures/models/natural/common_fall_orange1_3.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/common_fall_orange1_3.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 512
		rgbgen vertex
	}
}

static_common_fall_orange1_4 
{
	qer_editorimage textures/models/natural/common_fall_orange1_4.tga
	nomipmaps
	
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/common_fall_orange1_4.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbgen vertex
	}
}

static_common_fall_orange1_5 
{
	qer_editorimage textures/models/natural/common_fall_orange1_5.tga
	nomipmaps
	cull none



	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0




	{
		clampmap textures/models/natural/common_fall_orange1_5.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 256
		rgbgen vertex
	}
}

static_common_fall_orange1sprite 
{
	qer_editorimage textures/models/natural/tree1sprite.tga
	qer_trans 0
	nomipmaps
	deformVertexes autoSprite2
	cull none
	{
		clampmap textures/models/natural/tree1sprite.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 1216 512
		rgbgen vertex
	}
}

static_common_fall_red1_1	
{
	qer_editorimage textures/models/natural/common_fall_red1_1.tga
	{
		map textures/models/natural/common_fall_red1_1.tga
		alphaGen distFade 2304 0
		rgbgen vertex
	}
}

static_common_fall_red1_2 
{
	qer_editorimage textures/models/natural/common_fall_red1_2.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/common_fall_red1_2.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 512 256
		rgbgen vertex
	}
}

static_common_fall_red1_3 
{
	qer_editorimage textures/models/natural/common_fall_red1_3.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/common_fall_red1_3.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 512
		rgbgen vertex
	}
}

static_common_fall_red1_4 
{
	qer_editorimage textures/models/natural/common_fall_red1_4.tga
	nomipmaps
	
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/common_fall_red1_4.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbgen vertex
	}
}

static_common_fall_red1_5 
{
	qer_editorimage textures/models/natural/common_fall_red1_5.tga
	nomipmaps
	cull none



	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0




	{
		clampmap textures/models/natural/common_fall_red1_5.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 256
		rgbgen vertex
	}
}

static_common_fall_red1sprite 
{
	qer_editorimage textures/models/natural/tree1sprite.tga
	qer_trans 0
	nomipmaps
	deformVertexes autoSprite2
	cull none
	{
		clampmap textures/models/natural/tree1sprite.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 1216 512
		rgbgen vertex
	}
}

static_Crunchtree1_1	
{
	qer_editorimage textures/models/natural/tree1_1.tga
	{
		map textures/models/natural/tree1_1.tga
		alphaGen distFade 2304 0
		rgbgen vertex
	}
}

static_Crunchtree1_2 
{
	qer_editorimage textures/models/natural/tree1_2.tga
	nomipmaps
	cull none
	
	{
		clampmap textures/models/natural/Crunchtree1_2.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 512 256
		rgbgen vertex
	}
}

static_Crunchtree1_3 
{
	qer_editorimage textures/models/natural/tree1_3.tga
	nomipmaps
	cull none
	
	{
		clampmap textures/models/natural/tree1_3.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 512
		rgbgen vertex
	}
}

static_Crunchtree1_4 
{
	qer_editorimage textures/models/natural/tree1_4.tga
	nomipmaps
	
	
	{
		clampmap textures/models/natural/tree1_4.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbgen vertex
	}
}

static_Crunchtree1_5 
{
	qer_editorimage textures/models/natural/tree1_5.tga
	nomipmaps
	cull none



	



	{
		clampmap textures/models/natural/tree1_5.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1536 256
		rgbgen vertex
	}
}

static_Crunchtree1sprite 
{
	qer_editorimage textures/models/natural/tree1sprite.tga
	qer_trans 0
	nomipmaps
	
	cull none
	{
		clampmap textures/models/natural/tree1sprite.tga
		depthWrite
		alphaFunc GE128
		alphaGen oneMinusDistFade 1216 512
		rgbgen vertex
	}
}

static_vcredtree4_1 
{
	qer_editorimage textures/models/natural/vcredtree4_1.tga
	{
		map textures/models/natural/vcredtree4_1.tga
		rgbGen vertex
		alphaGen distFade 2000 600
	}
}

static_vcredtree4_2 
{
	qer_editorimage textures/models/natural/vcredtree4_2.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/vcredtree4_2.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 2000 1500
		rgbGen vertex
	}
}

static_vcredtree4_3 
{
	qer_editorimage textures/models/natural/vcredtree4_3.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/vcredtree4_3.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1400 1400
		rgbGen vertex
	}
}

static_vcredtree4_4 
{
	qer_editorimage textures/models/natural/vcredtree4radial.tga
	nomipmaps
	cull none
	deformVertexes wave 24 sin 0 0.5 0    0.2
	deformVertexes wave 24 sin 0 0.5 0.25 0.3
	{
		clampmap textures/models/natural/vcredtree4radial.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbGen vertex
	}
}

static_vctree4_1 
{
	qer_editorimage textures/models/natural/vctree4_1.tga
	{
		map textures/models/natural/vctree4_1.tga
		rgbGen vertex
		alphaGen distFade 2000 600
	}
}

static_vctree4_2 
{
	qer_editorimage textures/models/natural/vctree4_2.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/vctree4_2.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 2000 1500
		rgbGen vertex
	}
}

static_vctree4_3 
{
	qer_editorimage textures/models/natural/vctree4_3.tga
	nomipmaps
	cull none
	deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/vctree4_3.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 1400 1400
		rgbGen vertex
	}
}

static_vctree4_4 
{
	qer_editorimage textures/models/natural/vctree4radial.tga
	nomipmaps
	cull none
	deformVertexes wave 24 sin 0 0.5 0    0.2
	deformVertexes wave 24 sin 0 0.5 0.25 0.3
	{
		clampmap textures/models/natural/vctree4radial.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 256 256
		rgbGen vertex
	}
}

steak_steak
{
      qer_editorimage textures/milkshape/steak/steak.jpg
      cull none
      {
            map textures/milkshape/steak/steak.jpg
            rgbGen lightingSpherical
      }
}

triporteur_bnkrpipe1_blue
{
      qer_editorimage textures/milkshape/triporteur/bnkrpipe1_blue.jpg
      cull none
      {
            map textures/milkshape/triporteur/bnkrpipe1_blue.jpg
            rgbGen lightingSpherical
      }
}

triporteur_elephan
{
      qer_editorimage textures/milkshape/triporteur/elephan.jpg
      cull none
      {
            map textures/milkshape/triporteur/elephan.jpg
            rgbGen lightingSpherical
      }
}

triporteur_jagd11
{
      qer_editorimage textures/milkshape/triporteur/jagd11.jpg
      cull none
      {
            map textures/milkshape/triporteur/jagd11.jpg
            rgbGen lightingSpherical
      }
}

triporteur_jh_rivplate1
{
      qer_editorimage textures/milkshape/triporteur/jh_rivplate1.jpg
      cull none
      {
            map textures/milkshape/triporteur/jh_rivplate1.jpg
            rgbGen lightingSpherical
      }
}

triporteur_pak40-5
{
      qer_editorimage textures/milkshape/triporteur/pak40-5.jpg
      cull none
      {
            map textures/milkshape/triporteur/pak40-5.jpg
            rgbGen lightingSpherical
      }
}

triporteur_pneu
{
      qer_editorimage textures/milkshape/triporteur/pneu.jpg
      cull none
      {
            map textures/milkshape/triporteur/pneu.jpg
            rgbGen lightingSpherical
      }
}

triporteur_tripot
{
      qer_editorimage textures/milkshape/triporteur/tripot.jpg
      cull none
      {
            map textures/milkshape/triporteur/tripot.jpg
            rgbGen lightingSpherical
      }
}

