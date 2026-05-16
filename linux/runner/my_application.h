#ifndef FLUTTER_MY_APPLICATION_H_
#define FLUTTER_MY_APPLICATION_H_

#include <gtk/gtk.h>

G_DECLARE_FINAL_TYPE(MyApplication,
                     my_application,
                     MY,
                     APPLICATION,
                     GtkApplication)

/**
 * my_application_new:
 *
 * 创建一个新的基于 Flutter 的应用。
 *
 * 返回值：新的 #MyApplication。
 */
MyApplication *my_application_new();

#endif // FLUTTER_MY_APPLICATION_H_
