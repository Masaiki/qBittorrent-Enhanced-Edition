// Static Qt plugin imports for Windows platform integration.
// This file is automatically added to the build when using static Qt on Windows.
#include <QtGlobal>

#if defined(Q_OS_WIN) && !defined(DISABLE_GUI)
#include <QtPlugin>

Q_IMPORT_PLUGIN(QWindowsIntegrationPlugin)
Q_IMPORT_PLUGIN(QWindowsVistaStylePlugin)
Q_IMPORT_PLUGIN(QSvgIconPlugin)
Q_IMPORT_PLUGIN(QSvgPlugin)
Q_IMPORT_PLUGIN(QSQLiteDriverPlugin)

#endif
