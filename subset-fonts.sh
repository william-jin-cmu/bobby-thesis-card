#!/bin/zsh
# Re-run after changing UI copy: subsets Noto Serif SC to the characters used in Bobby/*.swift
cd "$(dirname "$0")"
SIM="${SIM:-booted}"
# fonts-src/ holds the full Noto Serif SC OTFs from github.com/notofonts/noto-cjk (SIL OFL 1.1); not committed.
python3 -c "
import glob
s=set()
for f in glob.glob('Bobby/*.swift'): s|=set(open(f).read())
s|=set(chr(c) for c in range(0x20,0x7f))|set('，。：；、！？「」《》（）—…·％→←≥≤×−–“”‘’')
open('/tmp/bobby-chars.txt','w').write(''.join(sorted(s)))"
for w in Regular Medium SemiBold; do
  pyftsubset fonts-src/NotoSerifSC-$w.otf --text-file=/tmp/bobby-chars.txt --output-file=Bobby/Fonts/NotoSerifSC-$w.otf --layout-features='*' --name-IDs='*'
done
ls -la Bobby/Fonts
