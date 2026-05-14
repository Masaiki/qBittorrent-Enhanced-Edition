// Static Qt plugin imports for Windows platform integration.
// This file is automatically added to the build when using static Qt on Windows.
// It provides the necessary Q_IMPORT_PLUGIN calls so that all plugins are
// statically linked into the executable, matching vcpkg's default auto-import
// behavior and eliminating all runtime DLL dependencies.
#include <QtGlobal>

#if defined(Q_OS_WIN) && !defined(DISABLE_GUI)
#include <QtPlugin>

// Platform
Q_IMPORT_PLUGIN(QWindowsIntegrationPlugin)

// Styles
Q_IMPORT_PLUGIN(QWindowsVistaStylePlugin)

// Icon engines
Q_IMPORT_PLUGIN(QSvgIconPlugin)

// Image formats
Q_IMPORT_PLUGIN(QSvgPlugin)
Q_IMPORT_PLUGIN(QICOPlugin)
Q_IMPORT_PLUGIN(QGifPlugin)
Q_IMPORT_PLUGIN(QJpegPlugin)

// SQL drivers
Q_IMPORT_PLUGIN(QSQLiteDriverPlugin)

#endif
