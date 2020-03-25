#!/usr/bin/python3
"""Convert a fixed-width BDF font to hex constants in Easy68k assembly.

Forfeited into the public domain with NO WARRANTY. Read LICENSE for details.

BDF is an old, simple bitmap font file format. Editors for BDF fonts are still
around, like `gbdfed` (http://sofia.nmsu.edu/~mleisher/Software/gbdfed/) and
`fony` (http://hukka.ncn.fi/?fony).

This relatively slapdash script makes some effort to convert a fixed-width BDF
font to an Easy68k assembly language file that encodes the font glyphs as
constant data, and font metrics as `EQU` constants. If it succeeds, the file
will be suitable for use with the macros in `lisa_console_screen.x68`.


## Revision history

This section records the development of this file as part of the `lisa_io`
library at <http://github.com/stepleton/lisa_io>.

    - 25 March 2020: Initial release.
      (Tom Stepleton, stepleton@gmail.com, London)
"""


import argparse
import itertools
import math
import re
import textwrap


# Command-line flags.
flags = argparse.ArgumentParser(
    description='Convert a fixed-width BDF font to Easy68k hex constants')

flags.add_argument('bdf_file',
                   help=('BDF font file to convert; if unspecified, font data '
                         'is read from standard input'),
                   type=argparse.FileType('r'),
                   default='-')

flags.add_argument('-v', '--vpad',
                   help=('How many pixels of vertical padding to put above '
                         'characters.'),
                   type=int,
                   default=1)

flags.add_argument('-o', '--output',
                   help=('Where to write the resulting Easy68k code; if '
                         'unspecified, the code is written to standard out'),
                   type=argparse.FileType('w'),
                   default='-')

FLAGS = flags.parse_args()


# Constants:
DISP_COLS = 720  # How many columns of pixels in the display?
DISP_ROWS = 364  # How many rows of pixels in the display?


# Argument checking
if not 0 <= FLAGS.vpad <= DISP_ROWS: raise ValueError(
    f'Argument to --vpad should be between 0 and {DISP_ROWS}')


# FSM State 0: Collect the font name.
for line in FLAGS.bdf_file:
  line = line.rstrip()
  m = re.match(r'FONT .+', line)
  if m:
    FONT_NAME = ''.join(w.capitalize() for w in m[0].split('-')[2].split(' '))
    break
else:
  raise RuntimeError('No FONT record found!')


# FSM State 1: Check font is a size we handle. Gather other config info.
for line in FLAGS.bdf_file:
  line = line.rstrip()
  m = re.fullmatch(r'FONTBOUNDINGBOX ([-\d]+) ([-\d]+) ([-\d]+) ([-\d]+)', line)
  if m:
    COLS, ROWS = int(m[1]), int(m[2])
    BL_COL, BL_ROW = int(m[3]), int(m[4])  # BL = bottom left
    break
else:
  raise RuntimeError('No FONTBOUNDINGBOX record found!')


# Print some top-level data and metrics for this font.
FLAGS.output.write(textwrap.dedent(f"""\
        ; The {FONT_NAME} font.
    kFont{FONT_NAME}GlyphBytes EQU {ROWS * math.ceil(COLS / 8)}
    kFont{FONT_NAME}GlyphCols  EQU {COLS}
    kFont{FONT_NAME}GlyphRows  EQU {ROWS}
    kFont{FONT_NAME}VertPad    EQU {FLAGS.vpad}
    kFont{FONT_NAME}ScreenCols EQU {DISP_COLS // COLS}
    kFont{FONT_NAME}ScreenRows EQU {DISP_ROWS // (ROWS + FLAGS.vpad)}


    define{FONT_NAME} MACRO
                  mFont8 {FONT_NAME},1,9
               ENDM


    font{FONT_NAME}:
    """))
    


# All other FSM states are executed sequentially to process character records.
for expected_codepoint in itertools.count():


  # FSM STATE 2: Await STARTCHAR or end-of-file.
  for line in FLAGS.bdf_file:
    line = line.rstrip()
    m = re.match(r'STARTCHAR (.+)', line)
    if m:
      CURR_CHAR = m[1]
      break
  else:
    break  # End of file reached.


  # FSM STATE 3: Await ENCODING. Check it matches the character we expect now.
  for line in FLAGS.bdf_file:
    line = line.rstrip()
    m = re.match(r'ENCODING (\d+)', line)
    if m:
      if int(m[1]) != expected_codepoint: raise RuntimeError(
          'Expected character {}, found {}'.format(expected_codepoint, m[1]))
      break
  else:
    raise RuntimeError('No ENCODING record for "{}"'.format(CURR_CHAR))


  # FSM STATE 4: Await BBX. Check fit and alignment to character bounds.
  for line in FLAGS.bdf_file:
    line = line.rstrip()
    m = re.match(r'BBX ([-\d]+) ([-\d]+) ([-\d]+) ([-\d]+)', line)
    if m:
      # Collect character bounds.
      C_COLS, C_ROWS = int(m[1]), int(m[2])
      C_BL_COL, C_BL_ROW = int(m[3]), int(m[4])

      # Check character bounds.
      C_COL_MIN = C_BL_COL - BL_COL
      C_COL_MAX = C_BL_COL - BL_COL + C_COLS
      C_ROW_MIN = C_BL_ROW - BL_ROW
      C_ROW_MAX = C_BL_ROW - BL_ROW + C_ROWS
      if (C_COL_MIN < 0 or C_COL_MAX > COLS or
          C_ROW_MIN < 0 or C_ROW_MAX > ROWS): raise RuntimeError(
          'Uncontained bbox "{}" for "{}"'.format(m[0], CURR_CHAR))

      # Now, when we read the bitmap, here are the rows we'll fill.
      C_ROW_INDS = list(
          ROWS - 1 - c for c in reversed(range(C_ROW_MIN, C_ROW_MAX)))

      break
  else:
    raise RuntimeError('No BBX record for "{}"'.format(CURR_CHAR))


  # FSM STATE 5: Await BITMAP.
  for line in FLAGS.bdf_file:
    if line.rstrip() == 'BITMAP': break
  else:
    raise RuntimeError('No BITMAP header for "{}"'.format(CURR_CHAR))


  # FSM STATE 6: Fill character bitmap.
  BITMAP = [0] * ROWS
  for r in C_ROW_INDS:
    row_bits = int(next(FLAGS.bdf_file), 16)
    BITMAP[r] = row_bits >> C_COL_MIN


  # FSM STATE 7: Note end of character bitmap.
  if next(FLAGS.bdf_file).rstrip() != 'ENDCHAR': raise RuntimeError(
      'No ENDCHAR footer for "{}"'.format(CURR_CHAR))


  # Print character data for this character bitmap.
  # Regrettably we can't define per-glyph symbols because Easy68k can't deal
  # with 21st-century lengths.
  print('* glyph' + FONT_NAME + ''.join(
      w.capitalize() for w in CURR_CHAR.split(' ')) + ':', file=FLAGS.output)
  row_byte_text = []
  for row_bits in BITMAP:
    # Print bits as a comment.
    row_bit_chars = '{{:{}b}}'.format(COLS).format(row_bits)
    print('    ;', ''.join(
        '#' if c == '1' else '.' for c in row_bit_chars), file=FLAGS.output)

    # Collect bits into hex bytes.
    while row_bit_chars:
      this_byte_chars, row_bit_chars = row_bit_chars[:8], row_bit_chars[8:]
      this_byte_chars += '0' * (8 - len(this_byte_chars))
      row_byte_text.append('${:02X}'.format(int(this_byte_chars, 2)))

  print('    DC.B    {}'.format(','.join(row_byte_text)), file=FLAGS.output)
  print('', file=FLAGS.output)


print('    ; End of font.', file=FLAGS.output)
