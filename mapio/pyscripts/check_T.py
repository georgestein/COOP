import time
import os
import sys
cclist = ['commander', 'nilc', 'sevem', 'smica']
nulist = ['0', '1']
hclist = ['hot0', 'cold0', 'hot1', 'cold1']
nslist = ['F', 'N', 'S']
readonly = 'T'
nmaps = 1000
print "=============== F =============="
for nu in nulist:
    print '------------------------'
    print "nu = " + nu
    for cc in cclist:
        print cc
        for hc in hclist:
#            print (r'./SST '+cc+' 1024 T ' + ' ' + nu + ' ' + str(nmaps) + ' self '+ hc + ' T F T ' + readonly )
            os.system(r'./SST '+cc+' 1024 T ' + ' ' + nu + ' ' + str(nmaps) + ' self '+ hc + ' T F T ' + readonly) # + r' > scripts/' + cc + r'T' + nu + r'F.log')
    

print "=========== NS ==========="

for nu in nulist:
    print '------------------------'    
    print "nu = " + nu
    for cc in cclist:
        print cc
        for ns in nslist:
            os.system(r'./SST ' + cc + ' 1024 T ' + ' ' + nu + ' ' + str(nmaps) + ' self hot0 T  ' + ns + ' T ' + readonly )
            os.system(r'./SST ' + cc + ' 1024 T ' + ' ' + nu + ' ' + str(nmaps) + ' self cold0 T ' + ns + ' T ' + readonly)                      
                    
