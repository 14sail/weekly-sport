# 回憶錄的縮圖：memories/*.jpg → memories/thumb/*.jpg
# 方格裡一格約 110px 寬，手機 3 倍螢幕要 330px，所以切成 360×360 正方形。
# 用法：python tools/make-thumbs.py（新增照片後再跑一次，已經有的會覆蓋）
import os, sys
from PIL import Image, ImageOps

SRC = os.path.join(os.path.dirname(__file__), '..', 'memories')
DST = os.path.join(SRC, 'thumb')
SIZE = 360

os.makedirs(DST, exist_ok=True)
total = 0
for name in sorted(os.listdir(SRC)):
    if not name.lower().endswith('.jpg') or name == 'finale.jpg':   # 結尾那張是整張放，不用縮圖
        continue
    im = Image.open(os.path.join(SRC, name))
    im = ImageOps.exif_transpose(im).convert('RGB')   # 手機直拍的照片要先轉正
    im = ImageOps.fit(im, (SIZE, SIZE), Image.LANCZOS, centering=(0.5, 0.4))  # 偏上一點，少切到頭
    out = os.path.join(DST, name)
    im.save(out, 'JPEG', quality=72, optimize=True, progressive=True)
    total += os.path.getsize(out)
print('done', round(total / 1024), 'KB', file=sys.stderr)
