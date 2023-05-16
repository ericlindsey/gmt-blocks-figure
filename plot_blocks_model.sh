#!/bin/bash
# script by Eric Lindsey to plot results of a Block model
# last modified May 2023

#########################
#
# set map-specific parameters here:
#
#########################

# prefix folder for location of block model results (e.g. 0000000001)
blocksprefix="/Users/elindsey/Dropbox/projects/myanmar/writing/Myanmar_Lindsey+21/data_models/blocks_JHC"

# set map region
Lx=90
Ty=25.5
Rx=98
By=15
region="$Lx/$Rx/$By/$Ty"

# name of a fault map file - used only when the map type is 'dataonly'
faultmap="../mapdata/myanmar_faults_all.txt"

# set scale for vectors
vecscale="-A+p1p+e+n15 -Se0.07/0.95/10"

#map projection and figure size, e.g. JM4i for a 4-inch wide map with mercator projection
JR="-JM4i -R$region"

# min/max color limits for slip rate colorscale
cptlim=20

#########################
#
# end of map-specific parameters
#
#########################

if [[ $# -lt 3 ]]; then
  echo "At least 3 arguments are required."
  echo "Usage: $0 <model_number (e.g. 17)> <map_type (strike/dip/geometryonly/dataonly)> <plot_resid (true/false)>"
  echo "Alternately, can provide 10 input options, but this should be done from another script"
  exit 1
fi

if [[ $# -eq 10 ]]; then
  #plotting as part of panels script
  model=$1
  maptype=$2
  plotstrain=$3
  panelid=$4
  Xoff=$5
  Yoff=$6
  ps=$7
  modellabel="Model $8"
  plotresid=$9
  plotmesh=${10}
else
  #use hard-coded values
  gmt set GMT_THEME classic
  gmt set MAP_TICK_LENGTH -5p
  gmt set MAP_FRAME_TYPE plain
  gmt set MAP_ANNOT_OFFSET 5p
  gmt set FONT_TITLE 10p,Helvetica,Black
  gmt set MAP_TITLE_OFFSET 5p
  gmt set FONT_ANNOT_PRIMARY 10p
  gmt set FONT_LABEL 10p
  gmt set PS_MEDIA a0
  model=$1
  maptype=$2 #strike/dip/geometryonly/dataonly
  plotstrain=false #true/false for strain crosses
  panelid=a
  Xoff=2
  Yoff=2
  ps="plot_Blocks_model_${maptype}_$model.ps"
  modellabel="Model $model:"
  plotresid=$3
  plotmesh=true
fi

# optional DEM settings:
# resolution of the dem, gradient azimuth and normalization for hillshade
demresolution=30s
demazimuth=90
demnormalization=0.6
#colormap style for DEM
demcpt="gray"

# elevaton map and its gradient
dem=dem_${demresolution}.grd
demgrad=dem_grad_${demresolution}_${demazimuth}_${demnormalization}.grd
if [[ ! -f $demgrad ]]; then
  ./get_dem.sh $Lx $Rx $By $Ty $demresolution $demazimuth $demnormalization
fi

linecpt=polar$cptlim.cpt
gmt makecpt -Cpolar -D -Z -T-$cptlim/$cptlim/0.1 > $linecpt

modelpad=`echo $model | awk '{printf("%03s\n",$1)}'`
modelzeropad=`echo $model | awk '{printf("%.10d\n",$1)}'`
blocksfolder="$blocksprefix/$modelzeropad"

# reformat the blocks outputs into columns
./reformat_blocksfile.sh $blocksfolder/Mod.segment $blocksfolder/Mod_segment.txt 13
./reformat_blocksfile.sh $blocksfolder/label.segment $blocksfolder/label_segment.txt 13
./reformat_blocksfile.sh $blocksfolder/Strain.block $blocksfolder/Strain_block.txt 8
./reformat_blocksfile.sh $blocksfolder/Mod.block $blocksfolder/Mod_block.txt 8 

if [[ $panelid == "a" ]]; then # first panel of a multi-panel figure, or a single-panel figure
  # first GMT command does not have an "-O", and only one arrow to the ps file.
  echo "gmt psbasemap -X$Xoff -Y$Yoff $JR -K -B0 > $ps"
  gmt psbasemap -X$Xoff -Y$Yoff $JR -K -B0 > $ps
else
  echo "gmt psbasemap -X$Xoff -Y$Yoff $JR -O -K -B0 >> $ps"
  gmt psbasemap -X$Xoff -Y$Yoff $JR -O -K -B0 >> $ps
fi

gmt grdimage $dem -I$demgrad -t80 -C$demcpt -J -R -O -K >>$ps
gmt pscoast -J -R -Df -W1/0.2p -I0/1p,skyblue -I1/1p,skyblue -I2/1p,skyblue -Slightblue -t30 -O -K >> $ps
gmt pscoast -J -R -Ba2f.5WSne -Ln0.15/0.04+c94/20+w200k -Na/0.2p,brown -O -K >> $ps

# plot faults
if [[ $maptype == "dataonly" ]]; then
  gmt psxy $faultmap -R -J -W.3p,red -O -K >>$ps
fi

if [[ $plotmesh == "true" && $maptype == "dip" && -f $blocksfolder/coupling.gmt ]]; then
  gmt psxy $blocksfolder/coupling.gmt -L -Ccoupling_cmap.cpt -J -R -O -K >> $ps
  gmt psscale -J -R -Ccoupling_cmap.cpt -Np -Dx0/-0.4i+w3i/0.18i+h -O -K -G0/1 -B1:"Slip rate deficit (coupling) ratio": >> $ps
fi

if [[ $plotmesh == "true" && $maptype == "geometryonly" && -f $blocksfolder/coupling.gmt ]]; then
  gmt psxy $blocksfolder/coupling.gmt -L -Gred -t80 -J -R -O -K >> $ps
fi

if [[ $maptype != "dataonly" ]]; then
    # read each segment to an array and extract needed values
    while IFS=' ' read -a ary; do
      # array contents:Name st_long st_lat end_long end_lat lock_dep ld_sig ld_toggle dip dip_sig dip_toggle ss_rate ss_sig ss_tog ds_rate ds_sig ds_tog ts_rate ts_sig ts_tog bur_dep bd_sig bd_tog fres fres_ov fres_other other1 other2 other3 other4 other5 other6 other7 other8 other9 other10 other11 other12
      segname="${ary[0]}"
      if [[ $segname != "Name" ]]; then
        coords1="${ary[1]} ${ary[2]}"
        coords2="${ary[3]} ${ary[4]}"
        lockdepth="${ary[5]}"
        dip="${ary[8]}"
        echo segname $segname
        # create patches showing projection of dipping surfaces
        if [[ $maptype == "geometryonly" && $dip != "90.0" ]]; then 
          point1=`echo $coords1 |awk '{printf("%s/%s",$1,$2)}'`
          boxwid=`echo $lockdepth $dip |awk '{print -$1*cos($2*3.14159265/180)/sin($2*3.14159265/180)}'`
          boxlen=`echo $coords2 |gmt mapproject -R -G$point1+uk |awk '{print $3}'`
          projaz=`echo $coords2 | gmt mapproject -Af$point1 |awk '{print $3}'`
          projection="-JOa$point1/$projaz/5i"
          echo -e "0 0 \n 0 $boxwid \n $boxlen $boxwid \n $boxlen 0 \n 0 0" | gmt mapproject -R-60/60/-60/60 $projection -I -Fk -C > projbox.dat
          gmt psxy projbox.dat $JR -Gred -W0.5p,red -t80 -O -K >> $ps
        fi
        # create colored lines with variable thickness
        if [[ $maptype == "strike" ]]; then
            rate=`echo ${ary[11]} |awk '{printf("%.1f",$1)}'`
            sigma=`echo ${ary[12]} |awk '{printf("%.1f",$1)}'`
        elif [[ $maptype == "dip" ]]; then
          #dip values may be in either line 6 or line 7, in which case the sign should be flipped. Check which sigma is not zero
          rate1="${ary[14]}"
          sigma1="${ary[15]}"
          rate2="${ary[17]}"
          sigma2="${ary[18]}"
	        if [[ $sigma1 == "0.0" || $sigma1 == "0.00000" ]]; then
            rate=`echo $rate2 |awk '{printf("%.1f",-1*$1)}'`
            sigma=`echo $sigma2 |awk '{printf("%.1f",$1)}'`
          else
            rate=`echo $rate1 |awk '{printf("%.1f",$1)}'`
            sigma=`echo $sigma1 |awk '{printf("%.1f",$1)}'`
          fi
        fi

        if [[ $maptype != "geometryonly" ]]; then
          #scale linewidth from mm/yr to points
          wscale=1
          lwid=`echo $rate $wscale |awk '{print sqrt($1*$1)*$2}'`
          echo -e ">-Z$rate\n $coords1\n $coords2" | gmt psxy -R -J -O -K -C$linecpt -W$lwid -t40 >> $ps
        fi
        echo -e "$coords1\n $coords2" | gmt psxy -R -J -O -K -W0.5p,black >> $ps

        if [[ $maptype != "geometryonly" ]]; then
          # label rate/uncertainty on selected fault segments, identified by name
          # use -w to avoid grep matching if one name is a subset of another
          if [[ -f labelfaults.txt ]]; then
            labelDarg=`grep -w $segname labelfaults.txt |cut -d\  -f 2`
          else
            # if the fault is not in the labelfaults.txt list, don't label it.
            labelDarg=""
          fi
          if [[ $labelDarg ]]; then
            echo label $segname
            clon=`echo $coords1 $coords2 |awk '{print ($1+$3)/2}'`
            clat=`echo $coords1 $coords2 |awk '{print ($2+$4)/2}'`
            # special case: set a specific label location for this one fault name
            if [[ $segname == "thailand_connect" ]]; then
              clon=97
              clat=19.3
            fi
            echo rate $rate $sigma
            echo "$clon $clat $rate @~\261@~ $sigma" | gmt pstext -J -R -O -K -N -F+f10p,Helvetica-Bold+jMC $labelDarg >> $ps
          fi
        fi
      fi
    done < $blocksfolder/Mod_segment.txt
    
    # add strain crosses
    if [[ $plotstrain == "true" ]]; then
      while IFS=' ' read -a ary; do
        blockname=${ary[0]}
        if [[ $blockname != "Name" ]]; then
          coords="${ary[1]} ${ary[2]}"
          strainvalues="${ary[11]} ${ary[12]} ${ary[13]}"
          #strainsigmas="${ary[14]} ${ary[15]} ${ary[16]}"
          #compute strain axes
          echo $coords $strainvalues | awk '{print $1,$2,(.5*($3+$5)+sqrt((($3-$5)/2)^2 +($4/2)^2))*1e9,(.5*($3+$5)-sqrt((($3-$5)/2)^2 +($4/2)^2))*1e9,180-.5*atan2(2*$4,$3-$5)*180/3.1413}' | gmt psvelo -J -R -Wblack -Sx.15 -A0.1/0.4/0.3 -V -O -K >> $ps
        fi
      done < $blocksfolder/Strain_block.txt
    fi
fi

# Plot GNSS data
if [[ $plotresid == "true" ]]; then
    awk '{print $1,$2,$3,$4,$5,$6,$7}' $blocksfolder/Res.sta |gmt psvelo -J -R $vecscale -L -Gmagenta -W.1,magenta -V -O -K >> $ps
    echo '91.6 15.7 10 0 0 0 0 Residual'|gmt psvelo -J -R -W.1p,magenta $vecscale -L -Gmagenta -O -K >> $ps
    chi2=`grep DOF $blocksfolder/Stats.txt |awk '{printf("%.1f",$8)}'`
    echo "90.5 16.2 @~\143@~@+2@+/d.o.f. $chi2" |gmt pstext -J -R -N  -F+f10p,Helvetica,Black+jML -O -K -D-0.1/-0.1 >> $ps
else
    if [[ $maptype != "geometryonly" ]]; then
      awk '{print $1,$2,$3,$4,$5,$6,$7}' $blocksfolder/Obs.sta |gmt psvelo -J -R $vecscale -L -Gblack -W.1,black -V -O -K >> $ps
      # add Model vectors
      if [[ $maptype != "dataonly" ]]; then
        awk '{print $1,$2,$3,$4,$5,$6,$7}' $blocksfolder/Mod.sta |gmt psvelo -J -R $vecscale -L -Gred -W.1,red -V -O -K >> $ps
      fi
    fi
    
    # legend for arrows
    if [[ $maptype != "geometryonly" ]]; then
      #echo '91.6 16.1 10 0 1 1 0 10 @~\261@~ 1 mm/yr'|gmt psvelo -J -R -W.1p,black $vecscale -L -Gblack -O -K >> $ps
      echo '91.6 16.1 10 0 0 0 0 10 mm/yr'|gmt psvelo -J -R -W.1p,black $vecscale -L -Gblack -O -K >> $ps
      if [[ $maptype != "dataonly" ]]; then
        echo '91.6 15.7 10 0 0 0 0 Model'|gmt psvelo -J -R -W.1p,red $vecscale -L -Gred -O -K >> $ps
      fi
      #echo "91.8 15.65 Rel. to Burma"|gmt pstext -F+f14p,Helvetica,Black -R -J -O -K >>$ps
    fi
fi

# add the panel label to the top right of the map, in a white box
if [[ $maptype == "strike" ]]; then
    echo "$Rx $Ty $modellabel strike slip" |gmt pstext -J -R -N -Gwhite -F+f10p,Helvetica,Black+jTR -O -K -D-0.1/-0.1 >> $ps
elif [[ $maptype == "dip" ]]; then
    echo "$Rx $Ty $modellabel dip slip" |gmt pstext -J -R -N -Gwhite -F+f10p,Helvetica,Black+jTR -O -K -D-0.1/-0.1 >> $ps
fi

if [[ $# -lt 7 ]]; then
  # if less than 7 arguments were passed in, assume this is the end of the plotting. 
  # finish the figure and convert to pdf.
  gmt psxy -J -R -O -T >> $ps
  gmt psconvert -A -Tf $ps
  open $(basename $ps .ps).pdf
else 
  # this script is running in a list, label the panel with a letter and keep going
  echo $Lx $Ty $panelid |gmt pstext -J -R -N -F+f10p,Helvetica-Bold,Black+jTR -O -K -D-0.2/-0.05 >> $ps
fi

