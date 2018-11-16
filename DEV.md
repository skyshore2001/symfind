# bug: windows下中文文件名乱码

问题一：如果在cmd下用symsvr/symscan扫描，生成的tags.repo.gz中文件名使用的是gbk编码。而默认vim使用utf-8编码导致查询时显示乱码。
问题二：如果在mingw（已设置使用utf-8）下扫描，首先是诸如"/d/project/xx"这样的路径无法识别，其次是它获得的文件名是utf-8编码的，传给stags扫描时，会报找不到文件错误。

解决方法：

- 要求不论是cmd还是mingw环境下用symscan扫描，写入tags.repo.gz要求使用utf-8编码。
- windows下的stags接收文件名参数时，使用gbk编码。
- 在mingw中将"/d/project/xx"这样的路径还原成"d:/project/xx"。

perl中识别系统：

- win32: $^O eq 'MSWin32'
- msys: $^O eq 'msys'
