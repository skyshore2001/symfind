# Bad javascript parsing for line comment
2017/05/02 19:23:46

Just `fn1` is parsed. Because there is a '//' tag in fn2 that is treated by line comment. So fn2 and other functions below cannot be parsed.

```javascript
function fn1() {
}

function fn2() {
	var css1 = css.replace(/\/\*(.|\s)*?\*\//g, '');
}

function fn3() {
}
```

Workaround: break the literal '//', e.g.

	var css1 = css.replace(/\/\*(.|\s)*?\*\/\s*/g, '');

