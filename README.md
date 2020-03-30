`lisa_io` -- basic low-level I/O routines for Lisa
==================================================

This repository is a library of several standalone assembly language software
components for accessing various standard input/output devices of the Apple
Lisa computer. "Standalone" means that no one component depends on any other.
This design aims to make it easier for programmers to use only the components
they need for their programs.

At time of writing, only some of the Lisa's standard I/O facilities, and only
some ways of using those facilities, are supported by this library. More may be
added as directed by need and spare time.


Documentation
-------------

Because people might choose to package individual library components into their
own software projects, nearly all important documentation---including
references, acknowledgements, and release history---appears within the source
code files themselves.


Library components
------------------

| Facility                 | Component                       | Notes        |
|--------------------------|---------------------------------|--------------|
| Keyboard and mouse       | [`lisa_console_kbmouse.x68`][1] |              |
| Text on the display      | [`lisa_console_screen.x68`][2]  | Needs a font |
| Parallel-port hard drive | [`lisa_profile_io.x68`][3]      | Relocatable  |
| Serial ports             | --                              | _TODO_       |
| Floppy drive(s)          | --                              | _TODO_       |
| Other parallel-port I/O  | --                              | _TODO_       |
| AppleNet card            | --                              | _TODO_       |

**Expanded notes:**

- "Needs a font": `lisa_console_screen.x68` is mostly a macro library that
  creates display code for 8-pixel-wide fixed-width font data supplied by you.
  The file [`font_Lisa_Console.x68`][4] contains an example of the font data
  the library requires, along with documentation, of course. Additionally, the
  program [`bdf_to_lisa_console_screen_x68.py`][5] can convert some fixed-width
  BDF font files to the necessary format.

[1]: lisa_console_kbmouse.x68
[2]: lisa_console_screen.x68
[3]: lisa_profile_io.x68
[4]: font_Lisa_Console.x68
[5]: bdf_to_lisa_console_screen_x68.py


Nobody owns `lisa_io`
---------------------

This I/O library and any supporting programs, software libraries, and
documentation distributed alongside it are released into the public domain
without any warranty. See the [LICENSE](LICENSE) file for details.
