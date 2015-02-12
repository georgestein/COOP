import time
import os
cclist = ['commander', 'nilc', 'sevem', 'smica']
nulist = ['0', '1']
hclist = ['hot0', 'cold0', 'hot1', 'cold1']
nslist = ['N', 'S']
readonly = 'T'
nmaps = 500
print "=============== F =============="
for nu in nulist:
    print '------------------------'
    print "nu = " + nu
    for cc in cclist:
        print cc
        for hc in hclist:        
            os.system(r'./SST '+cc+' 1024 T ' + ' ' + nu + ' ' + str(nmaps) + ' self '+ hc + ' T F T ' + readonly)
    

print "=========== NS ==========="

for nu in nulist:
    print '------------------------'    
    print "nu = " + nu
    for cc in cclist:
        print cc
        for ns in nslist:
            print "hemisphere: " + ns
            os.system(r'./SST ' + cc + ' 1024 T ' + ' ' + nu + ' ' + str(nmaps) + ' self hot0 T  ' + ns + ' T ' + readonly)
            os.system(r'./SST ' + cc + ' 1024 T ' + ' ' + nu + ' ' + str(nmaps) + ' self cold0 T ' + ns + ' T ' + readonly)                      
                    
