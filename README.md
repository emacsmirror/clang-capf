`clang-capf.el` (formerly `cpp-capf.el`)
========================================

This package provides a `completion-at-point` function to complete C/C++
code using [clang], offering context-base suggestions for functions,
variables and types without having to save the buffer.

While `clang-capf` doesn't require anything to be installed besides
`clang` as an external component, a better looking completion
front-end in Emacs, such as [ivy] might be worth recommending.

How to use
----------

Using [MELPA] and `use-package`, a minimal but sufficient setup might
look something like this:

	(use-package clang-capf
	  :after cc-mode
	  :config
	  (add-hook 'c-mode-hook
				(lambda ()
				  (add-hook 'completion-at-point-functions #'clang-capf
							nil t))))

This will let `completion-at-point` know that it should try
`clang-capf` _first_ when looking for completions, in `c-mode`
buffers.

Also make sure that `completion-at-point` or `complete-symbol` is
actually bound.

Example
-------

In vanilla Emacs:

![screenshot1]

With [ivy]:

![screenshot2]

Bugs
----

- After completing, no further text is added, although it might be
  useful to add `()` for functions or `{}` for structures.

Any further bugs or questions can be submitted to my [public
inbox][mail].

Copying
-------

`clang-capf.el` is distributed under the [CC0 1.0 Universal (CC0 1.0)
Public Domain Dedication][cc0] license.

[clang]: https://clang.llvm.org/
[ivy]: https://github.com/abo-abo/swiper#ivy
[MELPA]: https://melpa.org/#/clang-capf
[screenshot1]: https://files.catbox.moe/z51xx7.png
[screenshot2]: https://files.catbox.moe/nuunet.png
[mail]: https://lists.sr.ht/~zge/public-inbox
[cc0]: https://creativecommons.org/publicdomain/zero/1.0/deed
