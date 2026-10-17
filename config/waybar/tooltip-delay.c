/* tooltip-delay.c — LD_PRELOAD shim: make GTK3 tooltips pop after 50ms.
 *
 * GTK3 hardcodes its hover delay as `#define HOVER_TIMEOUT 500` in
 * gtk/gtktooltip.c, and the old `gtk-tooltip-timeout` setting has been
 * ignored since 3.10 ("Deprecated: This setting is ignored").  Waybar has
 * no config option for it either (open feature request #3271).
 *
 * The only tunable spot is after the timer is created: gtktooltip.c names
 * it immediately with
 *
 *   tooltip->timeout_id = gdk_threads_add_timeout_full (0, 500, ...);
 *   g_source_set_name_by_id (tooltip->timeout_id,
 *                            "[gtk+] tooltip_popup_timeout");
 *
 * so we interpose g_source_set_name_by_id and, for that exact source,
 * pull its ready_time forward to now + 50ms.  Everything else passes
 * straight through to the real GLib.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <glib.h>

#define TOOLTIP_DELAY_US ((gint64)50 * 1000)
#define TOOLTIP_SRC_NAME "[gtk+] tooltip_popup_timeout"

typedef void (*set_name_by_id_fn)(guint, const char *);
typedef GSource *(*find_by_id_fn)(GMainContext *, guint);
typedef void (*set_ready_time_fn)(GSource *, gint64);
typedef gint64 (*mono_fn)(void);

void g_source_set_name_by_id(guint id, const char *name)
{
    static set_name_by_id_fn real_set_name;
    if (!real_set_name)
        real_set_name = (set_name_by_id_fn)dlsym(RTLD_NEXT, "g_source_set_name_by_id");
    if (real_set_name)
        real_set_name(id, name);

    if (!name || strcmp(name, TOOLTIP_SRC_NAME) != 0)
        return;

    static find_by_id_fn real_find;
    static set_ready_time_fn real_set_ready;
    static mono_fn real_mono;
    if (!real_find)
        real_find = (find_by_id_fn)dlsym(RTLD_NEXT, "g_main_context_find_source_by_id");
    if (!real_set_ready)
        real_set_ready = (set_ready_time_fn)dlsym(RTLD_NEXT, "g_source_set_ready_time");
    if (!real_mono)
        real_mono = (mono_fn)dlsym(RTLD_NEXT, "g_get_monotonic_time");
    if (!real_find || !real_set_ready || !real_mono)
        return;

    GSource *src = real_find(NULL, id);
    if (src)
        real_set_ready(src, real_mono() + TOOLTIP_DELAY_US);
}
