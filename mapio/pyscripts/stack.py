import sys, os, string, math, re

outdir = "tmpmaps/"
spots_dir = "spots/"
stack_dir = "stacked/"
check_files = True

prefix = "simu"
imap_in = "simu/simu_temp_010a_n1024.fits"
imask = "planck14/dx11_v2_common_int_mask_010a_1024.fits"
polmap_in = "simu/simu_pol_010a_n1024.fits"
polmask = "planck14/dx11_v2_common_pol_mask_010a_1024.fits"
unit = "muK"   

fwhm_in = 10
threshold = 0
fwhm_out = 15


postfix = "_fwhm" + str(fwhm_out) + ".fits"
fullprefix = outdir + prefix

imap = fullprefix + "_I" + postfix
polmap = fullprefix + "_QU" + postfix 
tqtutmap = fullprefix + "_TQTUT" + postfix
zetamap = fullprefix + "_zeta" + postfix
emap  = fullprefix + "_E" + postfix
bmap = fullprefix + "_B" + postfix

if(not (os.path.isfile(imap_in)  and os.path.isfile(polmap_in) and os.path.isfile(imask) and os.path.isfile(polmask))):
    print "not all files exist; please check."
    sys.exit()
    
if(not (os.path.isfile(zetamap) and os.path.isfile(tqtutmap) and os.path.isfile(emap) and os.path.isfile(bmap) and os.path.isfile(imap) and os.path.isfile(polmap))):
    os.system("./ByProd  " + fullprefix + " " + imap_in + " " + polmap_in + " " + imask + " " + polmask + " " +  str(fwhm_in) + " " + str(fwhm_out))

    
def getspots(inputmap, st):
    if(threshold < 6):
        output =  prefix  + "_fwhm" + str(fwhm_out) + "_" + st + "_threshold" + str(threshold)+".txt"
    else:
        output =  prefix  + "_fwhm" + str(fwhm_out) + "_" + st + "_NoThreshold.txt"    
    if(check_files):
        if( os.path.isfile(spots_dir + output)):
            print spots_dir + output + " already exists, skipping..."
            return output
    os.system("./GetSpots " + inputmap + " " + st + " " + imask + " " + polmask + " " + spots_dir + output + " " + str(threshold) + " 0 0")
    return output


def stack(inputmap, spots, st):        
    if(check_files):
        if(string.find(inputmap, "QTUT")!=-1 and (st == "QU" or st == "QrUr")):
            if(st == "QrUr"):
                output = "QTr_on_" + spots
            else:            
                output = "QT_on_" + spots
        else:
            if(st == "QrUr"):
                output = "Qr_on_" + spots
            elif (st == "zeta"):
                output = "zeta_on_" + spots
            else:
                output = st[0] + "_on_"+spots
        if(os.path.isfile(stack_dir + output)):
            print stack_dir+output+ "  already exists, skipping..."
            return
    os.system("./Stack " + inputmap + " " + spots_dir+spots + " " + st + " " + imask + " " + polmask + " " + unit)
    os.system("../utils/fasy.sh "+stack_dir+output)


spots_tmax = getspots(imap, "Tmax")
spots_emax = getspots(emap, "Emax")
spots_bmax = getspots(bmap, "Bmax")
spots_zetamax = getspots(zetamap, "zetamax")
spots_tmax_orient = getspots(tqtutmap, "Tmax_QTUTOrient")
spots_ptmax = getspots(tqtutmap, "PTmax")
spots_pmax = getspots(polmap, "Pmax")

stack(imap, spots_tmax, "T")
stack(emap, spots_tmax, "E")
stack(bmap, spots_tmax, "B")
stack(zetamap, spots_tmax, "zeta")
stack(polmap, spots_tmax, "QrUr")
stack(polmap, spots_tmax, "QU")
stack(tqtutmap, spots_tmax, "QrUr")
stack(tqtutmap, spots_tmax, "QU")

stack(emap, spots_emax, "E")
stack(imap, spots_emax, "T")
stack(bmap, spots_emax, "B")
   
stack(imap, spots_bmax, "T")
stack(emap, spots_bmax, "E")
stack(bmap, spots_bmax, "B")

stack(zetamap, spots_zetamax, "zeta")
stack(imap, spots_zetamax, "T")
stack(emap, spots_zetamax, "E")
stack(bmap, spots_zetamax, "B")

stack(imap, spots_tmax_orient, "T")
stack(emap, spots_tmax_orient, "E")
stack(zetamap, spots_tmax_orient, "zeta")
stack(polmap, spots_tmax_orient, "QU")
stack(tqtutmap, spots_tmax_orient, "QU")

stack(polmap, spots_ptmax, "QU")
stack(polmap, spots_pmax, "QU")
stack(imap, spots_ptmax, "T")
stack(zetamap, spots_ptmax, "zeta")
stack(emap, spots_ptmax, "E")
stack(tqtutmap, spots_ptmax, "QU")







