SRC    = norx-hw_doc
VIEWER = okular

all: pdf view

pdf: $(SRC).pdf

%.pdf: %.tex
	pdflatex $(SRC).tex

view:
	$(VIEWER) $(SRC).pdf &

clean:
	@echo "***** Cleaning the LaTeX directory structure."
	@rm -rf *.acr *.alg *.bbl *.blg *.glg *.gls *.aux *.glo *.ist
	@rm -rf *.lof *.log *.lot *.toc *.acn *.out *.tex~ *.tex.backup
	@rm -rf *.fdb_latexmk *.fls Makefile~ pso.conv-* auto *.hst *.ver 
	@rm -rf ./tables/*.log ./tables/*.tex~
