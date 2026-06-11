import cv2
for fn in ('_dma_c1.jpg','_dma_c2.jpg'):
    img=cv2.imread('tools/'+fn)
    roi=img[200:800, 800:1600]
    b,g,r=[roi[:,:,i].mean() for i in range(3)]
    dom=max([('R',r),('G',g),('B',b)],key=lambda t:t[1])[0]
    print(f'{fn}: BGR=({b:.0f},{g:.0f},{r:.0f}) dominant={dom}')
