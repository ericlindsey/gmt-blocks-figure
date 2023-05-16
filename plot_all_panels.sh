#!/usr/local/bin/bash

#pass variables to each panel command

gmt set GMT_THEME classic
gmt set MAP_TICK_LENGTH -5p
gmt set MAP_FRAME_TYPE plain
gmt set MAP_ANNOT_OFFSET 5p
gmt set FONT_TITLE 10p,Helvetica,Black
gmt set MAP_TITLE_OFFSET 5p
gmt set FONT_ANNOT_PRIMARY 10p
gmt set FONT_LABEL 10p
gmt set PS_MEDIA a0

# variables needed, in order:

# model (number 29 etc)
# maptype strike/dip/geometryonly/dataonly
# plotstrain true/false
# panelnum
# psfilename
# Model label
# plot resid
# plot mesh

ps=figure_5.ps
xoff=4.3i

./plot_blocks_model.sh 22 strike          false a 2       3 $ps A false false
./plot_blocks_model.sh 22 dip             false b $xoff   0 $ps A true  true

#finish figure
gmt psxy -J -R -O -T >> $ps
gmt psconvert -A -Tf $ps
open $(basename $ps .ps).pdf

