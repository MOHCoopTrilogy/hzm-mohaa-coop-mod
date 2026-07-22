// coop_1936_imports.shader
// Auto-generated for HZM coop build-mode: shader defs for the 30 imported '1936' mod
// placeable objects (build-mode catalog cats 35/36). Each block was lifted verbatim from
// the 1936 v0.77 pk3 shader scripts; only the blocks these models reference are included,
// so nothing here overrides a vanilla or existing-mod shader (verified 0 name collisions).
// Source: 1936 SCW total conversion (moddb.com/mods/1936). See _research/named_mods_objects.md.

ba6
{
	qer_editorimage textures/models/vehicles/ba6/ba6.tga
	surfaceparm metal
	nopicmip
	{
		map textures/models/vehicles/ba6/ba6.tga
		alphaFunc GE128
		rgbGen lightingSpherical
	}
}

caballo
{
	qer_editorimage textures/models/vehicles/caballo/caballo.jpg
	{
		map textures/models/vehicles/caballo/caballo.jpg
		rgbGen lightingSpherical
	}
}

CornLowPoly_cornpatch3
{
      qer_editorimage textures/milkshape/CornLowPoly/cornpatch3.tga
      cull none
      {
            map textures/milkshape/CornLowPoly/cornpatch3.tga
            rgbGen lightingSpherical
      }
}

falange2
{
	qer_editorimage textures/models/static/falange/falange.jpg
	surfaceparm metal
	{
		map textures/models/static/falange/falange.jpg
		rgbGen lightingSpherical
	}
}

GrassTall_GrassTall
{
qer_editorimage textures/milkshape/GrassTall/GrassTall.tga
deformVertexes flap t 24 sin 0 2.5 0    0.2 1 0
deformVertexes flap t 24 sin 0 2.5 0.25 0.3 1 0
{
map textures/milkshape/GrassTall/GrassTall.tga
alphafunc GE128
rgbGen vertex
}
}

lancia_cull
{
	qer_editorimage textures/models/vehicles/lancia/lancia.jpg
	surfaceparm metal
	{
		map textures/models/vehicles/lancia/lancia.jpg
		rgbGen lightingSpherical
	}
}

lancia_nocull
{
	qer_editorimage textures/models/vehicles/lancia/lancia.jpg
	surfaceparm metal
	cull none
	{
		map textures/models/vehicles/lancia/lancia.jpg
		rgbGen lightingSpherical
	}
}

maxim
{
	qer_editorimage	textures/models/weapons/maxim/maxim.jpg
	{
		map textures/models/weapons/maxim/maxim.jpg
		rgbGen lightingSpherical
	}
}

mohpa_backwall_top
{
	qer_editorimage textures/models/natural/mohpa_backwall_top.tga
	qer_trans 0
	nomipmaps
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/mohpa_backwall_top.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 5120 1024
		rgbgen lightingSpherical
	}
}

mohpa_tall_skinny
{
	qer_editorimage textures/models/natural/mohpa_tall_skinny.tga
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/mohpa_tall_skinny.tga
		depthWrite
		alphafunc GE128
		alphaGen distFade 5120 1024
		rgbGen lightingSpherical
	}
}

mohpa_tall_skinny_trunk
{
	qer_editorimage textures/models/natural/mohpa_tall_skinny.tga
	{
		map textures/models/natural/mohpa_tall_skinny.tga
		rgbGen lightingSpherical
	}
}

mohpa_thin_branch
{
	qer_editorimage textures/models/natural/mohpa_thin_branch.tga
	nomipmaps
	deformVertexes flap t 24 sin 0 3.5 0    0.2 1 0
	deformVertexes flap t 24 sin 0 3.5 0.25 0.3 1 0
	{
		clampmap textures/models/natural/mohpa_thin_branch.tga
		depthWrite
		alphaFunc GE128
		alphaGen dot
		rgbGen lightingGrid
	}
}

mohpa_trunk
{
	qer_editorimage textures/models/natural/mohpa_trunk.tga
	{
		map textures/models/natural/mohpa_trunk.tga
		rgbGen lightingSpherical
	}
}

muro
{
	qer_editorimage textures/models/static/muro/muro.jpg
	{
		map textures/models/static/muro/muro.jpg
		alphaFunc GE128
		depthWrite
	nextbundle
		map $lightmap
	}
}

nacional
{
	qer_editorimage textures/models/1936/banderas/nacional.jpg
	cull none
	deformVertexes flap s 128 sin .5 6 1   -1 0 2
	deformVertexes flap s 64 sin   1 3 0.5 -1 0 1.5
	{
		map textures/models/1936/banderas/nacional.jpg
		rgbgen static
        }
}

neutral
{
	qer_editorimage textures/models/1936/banderas/neutral.jpg
	cull none
	deformVertexes flap s 128 sin .5 6 1   -1 0 2
	deformVertexes flap s 64 sin   1 3 0.5 -1 0 1.5
	{
		map textures/models/1936/banderas/neutral.jpg
		rgbgen static
        }
}

republicana
{
	qer_editorimage textures/models/1936/banderas/republicana.jpg
	cull none
	deformVertexes flap s 128 sin .5 6 1   -1 0 2
	deformVertexes flap s 64 sin   1 3 0.5 -1 0 1.5
	{
		map textures/models/1936/banderas/republicana.jpg
		rgbgen static
        }
}

seto
{
	qer_editorimage textures/models/natural/seto.tga
	nomipmaps
	cull none
	{
		clampmap textures/models/natural/seto.tga
		depthWrite
		alphaFunc GE128
		alphaGen distFade 4096 256
		rgbGen lightingGrid
	}
}

soporte
{
	qer_editorimage	textures/models/weapons/maxim/carro.jpg
	{
		map textures/models/weapons/maxim/carro.jpg
		rgbGen lightingSpherical
	}
}

t26r
{
	qer_editorimage textures/models/vehicles/t26/t26r.tga
	surfaceparm metal
	nopicmip
	{
		map textures/models/vehicles/t26/t26r.tga
		alphaFunc GE128
		rgbGen lightingSpherical
	}
}

t26r_d
{
	qer_editorimage textures/models/vehicles/t26/t26r_d.tga
	surfaceparm metal
	nopicmip
	{
		map textures/models/vehicles/t26/t26r_d.tga
		alphaFunc GE128
		rgbGen lightingSpherical
	}
}

unl35
{
	qer_editorimage textures/models/vehicles/unl35/unl35.tga
	surfaceparm metal
	{
		map textures/models/vehicles/unl35/unl35.tga
		rgbGen lightingSpherical
	}
}

ventanacuartel
{
	qer_editorimage textures/models/barcelona/ventana.jpg
	surfaceparm stone
	{
		map textures/models/barcelona/ventana.jpg
		rgbGen lightingSpherical
	}
}

ventanacurva
{
	qer_editorimage textures/models/barcelona/ventana3.jpg
	surfaceparm glass
	{
		map textures/models/barcelona/ventana3.jpg
		rgbGen lightingSpherical
	}
}

ventanadintel
{
	qer_editorimage textures/models/barcelona/ventana4.jpg
	surfaceparm glass
	{
		map textures/models/barcelona/ventana4.jpg
		rgbGen lightingSpherical
	}
}

ventanareja
{
	qer_editorimage textures/models/barcelona/ventanareja.jpg
	surfaceparm wood
	{
		map textures/models/barcelona/ventanareja.jpg
		rgbGen lightingSpherical
	}
}

VGstove_vgfiller01
{
      qer_editorimage textures/milkshape/VGstove/vgfiller01.tga
qer_keyword vg
      cull none
      {
            map textures/milkshape/VGstove/vgfiller01.tga
            rgbGen lightingSpherical
      }
}

VGstove_vgfiller02
{
      qer_editorimage textures/milkshape/VGstove/vgfiller02.tga
      cull none
      {
            map textures/milkshape/VGstove/vgfiller02.tga
            rgbGen lightingSpherical
      }
}

VGstove_VGStovedoor
{
      qer_editorimage textures/milkshape/VGstove/VGstovedoor.tga
qer_keyword vg
      cull none
      {
            map textures/milkshape/VGstove/VGstovedoor.tga
            rgbGen lightingSpherical
      }
}

VGstove_VGStoveglass
{
      qer_editorimage textures/milkshape/VGstove/VGstoveglass.tga
qer_keyword vg
      cull none
      {
            map textures/milkshape/VGstove/VGstoveglass.tga
		blendFunc blend
		rgbGen identity
            rgbGen lightingSpherical
      }
}

VGstove_VGStovemain
{
      qer_editorimage textures/milkshape/VGstove/VGstovemain.tga
qer_keyword vg
      cull none
      {
            map textures/milkshape/VGstove/VGstovemain.tga
            rgbGen lightingSpherical
      }
}

VGstove_vgStoveshelve
{
      qer_editorimage textures/milkshape/VGstove/vgStoveshelve.tga
qer_keyword vg
      cull none
      {
            map textures/milkshape/VGstove/vgStoveshelve.tga
            rgbGen lightingSpherical
      }
}

zis5
{
	qer_editorimage textures/models/vehicles/zis5/zis5.tga
	{
		map textures/models/vehicles/zis5/zis5.tga
		rgbGen lightingSpherical
	}
}

zis5a
{
	qer_editorimage textures/models/vehicles/zis5/zis5a.tga
	surfaceparm metal
	{
		map textures/models/vehicles/zis5/zis5a.tga
		alphaFunc GE128
		rgbGen lightingSpherical
	}
}
