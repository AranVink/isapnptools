@ECHO OFF
ECHO Simple batch file to compile isapnp using Borland C/C++ 3.1 (Turbo C/C++ 3.0)
ECHO Set CC prior to executing to bcc or tcc, eg set CC=bcc or set CC=tcc
ECHO you should include INCLUDE directories if needed (-I c:\bc\include)
ECHO NOTE: all *.obj and *.lib files are removed before compile is attempted!
ECHO You may safely ignore the warnings about parameter/value never used.
ECHO .
ECHO Press ctrl-C to cancel or
pause

REM tlib (and possibly other tools) can't handle a dash in name

REM change to src directory (or copy makeDOSr.bat to src dir & comment out CD)
CD src

if %CC%!==! goto nocompiler
set CFLAGS=-DHAVE_CONFIG_H -ml
set INCLUDES=-I../include

ECHO Removing any object, library, map, and executable (exe) files in current directory 
del *.obj
del *.lib
del *.map
del *.exe

ECHO Compiling...
REM split into multiple compiles due to command line limits
%CC% %INCLUDES% %CFLAGS% -c callback.c cardinfo.c getopt.c getopt1.c iopl.c
%CC% %INCLUDES% %CFLAGS% -c mysnprtf.c isapnp.c pnp_acce.c pnpdump.c
%CC% %INCLUDES% %CFLAGS% -c pnp_sele.c realtime.c release.c res_acce.c
%CC% %INCLUDES% %CFLAGS% -c resource.c isapnp_m.c  pnpdumpm.c

ECHO Making initial lib (all obj files common to isapnp and pnpdump)
REM provides the library and useful for splitting into multiple command lines
tlib isapnp.lib /C +callback.obj +iopl.obj +pnp_acce.obj +res_acce.obj +realtime.obj
tlib isapnp.lib /C +cardinfo.obj +pnp_sele.obj +resource.obj +mysnprtf.obj +release.obj
tlib isapnp.lib /C +getopt.obj +getopt1.obj
copy isapnp.lib pnpdump.lib > nul

ECHO Making isapnp.lib  (libisapnp.a)
tlib isapnp.lib /C +isapnp_m.obj 
del isapnp.bak

ECHO Making pnpdump.lib  (libpnpdump.a)
tlib pnpdump.lib /C +pnpdumpm.obj
del pnpdump.bak


ECHO Linking executables (isapnp.exe and pnpdump.exe)
%CC% -tDe %CFLAGS% -eisapnp.exe isapnp.obj isapnp.lib
%CC% -tDe %CFLAGS% -epnpdump.exe pnpdump.obj pnpdump.lib

:cleanup
del *.obj

goto done

:nocompiler
ECHO you must set CC prior to executing this batch file.

:done
ECHO done

REM change back to original directory (comment out if compile.bat in src)
CD ..
