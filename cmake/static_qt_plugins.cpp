// Static Qt plugin imports for Windows platform integration.
// This file is automatically added to the build when using static Qt on Windows.
// It provides the necessary Q_IMPORT_PLUGIN calls so that the platform plugin
// (qwindows) is statically linked into the executable, avoiding the runtime
// dependency on qwindows.dll.
#include <QtGlobal>

#if defined(Q_OS_WIN) && !defined(DISABLE_GUI)
#include <QtPlugin>
Q_IMPORT_PLUGIN(QWindowsIntegrationPlugin)
#endif
