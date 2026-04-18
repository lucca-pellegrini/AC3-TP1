# SPDX-License-Identifier: ISC
# SPDX-FileCopyrightText: Copyright © 2026 Lucca M. A. Pellegrini <lucca@verticordia.com>

NAME := "A_Quantitative_Cache_Evaluation_of_Select_PolyBench_Kernels_-_Andrade_Canizela_Dimas_Jordão_Pellegrini"

MAIN := "main"
VER := `git describe --long --tags | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g'`
LATEX := `realpath ../gem5/venv/bin/python` + " latexrun --latex-cmd pdflatex"
LATEXFLAGS := "-O build -Wall"
CLEANFLAGS := "--clean-all -O build"
RELEASE := NAME + "_" + VER

all: pdf

pdf:
	{{LATEX}} {{LATEXFLAGS}} {{MAIN}}.tex

release: release-zip release-tar-gz release-tar-xz release-tar-zst

release-pdf: pdf
	gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/prepress \
		-dNOPAUSE -dQUIET -dBATCH -sOutputFile={{RELEASE}}.pdf        \
		{{MAIN}}.pdf

release-tar: release-pdf
	tar -vcf {{RELEASE}}.tar {{RELEASE}}.pdf

release-tar-gz: release-tar
	gzip -kf {{RELEASE}}.tar

release-tar-xz: release-tar
	xz -kf {{RELEASE}}.tar

release-tar-zst: release-tar
	zstd -qf {{RELEASE}}.tar

release-zip: pdf release-pdf
	zip -r {{RELEASE}}.zip {{RELEASE}}.pdf

clean:
	{{LATEX}} {{CLEANFLAGS}}
	rm -rf *.pdf *.ps *.idx *.bbl *.brf *.glo *.dvi *.toc *.lof *.aux  \
		*.log *.blg *.ilg *.ind *.out *.wsp *.fls *.synctex* *.zip \
		*.tar *.tar.gz *.tar.xz *.tar.zst *.*~ .*.stamp build/

# vim: noet ts=8 sts=8 sw=8
