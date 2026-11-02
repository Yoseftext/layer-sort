"""Render original SVG boards with already-installed librsvg/Cairo; no added dependency."""
import ctypes as C
from pathlib import Path
r=C.CDLL('librsvg-2.so.2');c=C.CDLL('libcairo.so.2');g=C.CDLL('libgobject-2.0.so.0')
r.rsvg_handle_new_from_data.argtypes=[C.c_char_p,C.c_size_t,C.c_void_p];r.rsvg_handle_new_from_data.restype=C.c_void_p
r.rsvg_handle_render_cairo.argtypes=[C.c_void_p,C.c_void_p];r.rsvg_handle_render_cairo.restype=C.c_int
c.cairo_image_surface_create.argtypes=[C.c_int,C.c_int,C.c_int];c.cairo_image_surface_create.restype=C.c_void_p
c.cairo_create.argtypes=[C.c_void_p];c.cairo_create.restype=C.c_void_p
c.cairo_surface_write_to_png.argtypes=[C.c_void_p,C.c_char_p];c.cairo_surface_write_to_png.restype=C.c_int
c.cairo_destroy.argtypes=[C.c_void_p];c.cairo_surface_destroy.argtypes=[C.c_void_p];g.g_object_unref.argtypes=[C.c_void_p]
for path in Path(__file__).parent.glob('*-concept.svg'):
 data=path.read_bytes();handle=r.rsvg_handle_new_from_data(data,len(data),None);assert handle
 surface=c.cairo_image_surface_create(0,1440,1250);context=c.cairo_create(surface)
 assert r.rsvg_handle_render_cairo(handle,context)
 assert c.cairo_surface_write_to_png(surface,str(path.with_suffix('.png')).encode())==0
 c.cairo_destroy(context);c.cairo_surface_destroy(surface);g.g_object_unref(handle)
 print(path.with_suffix('.png'))
