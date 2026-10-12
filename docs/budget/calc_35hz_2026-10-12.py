N=605; rps=17.5; f=N*rps; P=1e6/f
print("slice/s/face",f,"period us",P)
fr=64+64+24+(1920*8+8)+64
for d in (150,166.667,170):
    t=fr/d; print("seq",d,"MHz frame",fr,"=",round(t,2),"us fps",round(1e6/t),"margin %",round((P-t)/P*100,2))
print("dclk min",fr*f/1e6)
# uplink
beats=1728*3*64/63
for lr,nl,bps in ((800,12,3),(1000,12,3),(900,12,3),(800,18,2)):
    br=lr/16*1e6  # beats/s (2 words of 8bit per lane per beat)
    b=1728*bps*64/63
    t=b/br*1e6; print("uplink",lr,nl,"lanes frame us",round(t,2),"margin %",round((P-t)/P*100,1))
print("needed line rate 12 lanes",800*(beats/50e6*1e6)/P)
# DDR
rd=2*82944*f/1e6
print("DDR PL direct MB/s",rd,"vs 1786 margin%",(1786-rd)/1786*100, "per slice us",82944/893)
print("RGB565 8bit palette",rd/2)
# CPU slicing: write + read
for cf in (5,10,17.5):
    w=2*82944*N*cf/1e6; print("cpu slicing content",cf,"write MB/s",w,"total",w+rd)
# display
for g,p in ((166.667,3),(150,4),(170,3)):
    G=g*p; fps=G*1e6/(48*16*52); print("disp dclk",g,"GCLK",G,"fps",round(fps),"margin",round((fps-f)/f*100,1))
    print("  gray upper bound GCLK*T/48 =",G*P/48)
print("vendor table disp fps @600", 600e6/(45*74*52))
print("10bit need GCLK MHz",48*f*(1024+320)/1e6)
# wifi
for kb in (220,488):
    for cf in (17.5,35): print("wifi",kb,cf,kb*1e3*8*cf/1e6,"Mbit")
# uplink payload per face
print("uplink payload per face Gbps",1728*72*8*f/1e9)
