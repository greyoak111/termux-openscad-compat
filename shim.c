/* boost 1.92 把 program_options::arg 挪进了 detail::；老 openscad 引用旧名。
   旧名在新库里就是 detail::arg 这个 24 字节对象，这里原样放一个（内容全零，boost 只当标记用）。 */
char _ZN5boost15program_options3argE[24];
