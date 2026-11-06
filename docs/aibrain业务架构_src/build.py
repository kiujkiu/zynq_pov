#!/usr/bin/env python3
"""合成 aibrain 业务架构单文件 HTML。改 data.js / body.html 后重跑。"""
import pathlib
d=pathlib.Path(__file__).resolve().parent
rd=lambda n:(d/n).read_text(encoding='utf-8')
html=f'''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>aibrain 业务架构 v1</title><style>body{{margin:0}}[hidden]{{display:none!important}}img{{max-width:100%}}</style><style>{rd('style.css')}</style></head><body>
{rd('body.html')}
<script>
{rd('data.js')}
{rd('render.js')}
</script>
</body></html>'''
out=d.parent/'aibrain业务架构_v1_2026-11-05.html'
out.write_text(html,encoding='utf-8'); print(out,len(html))
