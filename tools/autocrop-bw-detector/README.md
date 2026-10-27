# 黑白底片边框检测器

从黑白底片预览图识别居中近矩形画幅，输出 Lightroom 归一化裁切坐标。低对比度、偏离中心、形状不可信的图片会被拒绝。

这是基于 stecman AutoCrop（CC0）的 Windows/黑白适配，保留上游署名与许可；不作为从零原创算法宣传。仅发布检测器源码，未包含 Lightroom 插件和 Python 运行时。

```sh
python -m pip install -r requirements.txt
python detect.py --help
python detect.py sample.jpg
```

输出文件及参数以 `--help` 为准。请先对图片副本操作。合成样本测试不能替代实际底片与 Lightroom 集成验证。
