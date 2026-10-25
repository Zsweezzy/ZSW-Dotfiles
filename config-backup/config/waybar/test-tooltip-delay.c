/* test-tooltip-delay.c — proves the shim cuts a 500ms timer to 50ms.
 *
 * Mirrors gtktooltip.c exactly: create a 500ms timeout, then name it
 * "[gtk+] tooltip_popup_timeout".  Run without LD_PRELOAD -> ~500ms,
 * with it -> ~50ms.
 *
 *   gcc -o /tmp/opencode/test-tooltip test-tooltip-delay.c $(pkg-config --cflags --libs glib-2.0)
 */
#include <glib.h>
#include <stdio.h>

static gint64 t0;
static GMainLoop *loop;

static gboolean fire(gpointer data)
{
    (void)data;
    printf("timer fired after %lld ms\n",
           (long long)((g_get_monotonic_time() - t0) / 1000));
    g_main_loop_quit(loop);
    return G_SOURCE_REMOVE;
}

int main(void)
{
    loop = g_main_loop_new(NULL, FALSE);
    t0 = g_get_monotonic_time();
    guint id = g_timeout_add(500, fire, NULL);
    g_source_set_name_by_id(id, "[gtk+] tooltip_popup_timeout");
    g_main_loop_run(loop);
    g_main_loop_unref(loop);
    return 0;
}
