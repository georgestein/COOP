# Plotting routines based on Andrea Zonca's examples.

import healpy as hp
from newsetup_matplotlib import *
from planckcolors import planck_parchment_cmap, planck_grey_cmap, colombi1_cmap
from matplotlib import cm


def plotmap(m, filename, title=None, vmin=None, vmax=None, units='',
            cbar=True, mask=None, ctab='parchment', width=8.8, grat=False):

    nside = hp.npix2nside(len(m))

    # setup colourmap
    
    if ctab == 'parchment':
        cmap = planck_parchment_cmap
    elif ctab == 'grey':
        cmap = cm.binary
    else:
        cmap = cm.binary

    # using matplotlib directly instead of mollview has higher quality
    # output, I plan to merge this into healpy

    # ratio is always 1/2
    xsize = 2000
    ysize = xsize/2.0

    theta = np.linspace(np.pi, 0, ysize)
    phi = np.linspace(-np.pi, np.pi, xsize)
    longitude = np.radians(np.linspace(-180, 180, xsize))
    latitude = np.radians(np.linspace(-90, 90, ysize))

    # project the map to a rectangular matrix xsize x ysize
    PHI, THETA = np.meshgrid(phi, theta)
    grid_pix = hp.ang2pix(nside, THETA, PHI)


    if mask != None:
        m = np.ma.masked_array(m, np.logical_not(mask))
        grid_mask = m.mask[grid_pix]
        grid_map = np.ma.MaskedArray(m[grid_pix], grid_mask)
    else:
        grid_map = m[grid_pix]

    from matplotlib.projections.geo import GeoAxes

    class ThetaFormatterShiftPi(GeoAxes.ThetaFormatter):
        """Shifts labelling by pi

        Shifts labelling from -180,180 to 0-360"""
        def __call__(self, x, pos=None):
            if x != 0:
                x *= -1
            if x < 0:
                x += 2*np.pi
            return GeoAxes.ThetaFormatter.__call__(self, x, pos)

    fig = plt.figure(figsize=(cm2inch(width), cm2inch(width)))
    # matplotlib is doing the mollweide projection
    ax = fig.add_subplot(111, projection='mollweide')

    # remove white space around the image
    #plt.subplots_adjust(left=0.01, right=0.99, top=0.95, bottom=0.01)

    # rasterized makes the map bitmap while the labels remain
    # vectorial flip longitude to the astro convention
    image = plt.pcolormesh(longitude[::-1], latitude, grid_map, vmin=vmin,
                           vmax=vmax, rasterized=True, cmap=cmap)

    if grat:
        # graticule
        ax.set_longitude_grid(60)
        ax.xaxis.set_major_formatter(ThetaFormatterShiftPi(60))
        if width < 10:
            ax.set_latitude_grid(45)
            ax.set_longitude_grid_ends(90)

    if cbar:
        # colorbar
        cb = fig.colorbar(image, orientation='horizontal', shrink=.4,
                          pad=0.05, ticks=[vmin, vmax])
        cb.ax.xaxis.set_label_text(units)
        cb.ax.xaxis.labelpad = -8
        # workaround for issue with viewers, see colorbar docstring
        cb.solids.set_edgecolor("face")

    ax.tick_params(axis='x', labelsize=10)
    ax.tick_params(axis='y', labelsize=10)
        
    # remove tick labels
    ax.xaxis.set_ticklabels([])
    ax.yaxis.set_ticklabels([])
    # remove grid
    #ax.xaxis.set_ticks([])
    #ax.yaxis.set_ticks([])

    if title != None:
        plt.title(title, fontsize='small')

    plt.grid(grat)

    # remove white space around the image horizontally, vertically the
    # space is removed directly by savefig bbox_inches="tight"

    #plt.subplots_adjust(left=0.01, right=0.99)
    plt.savefig(filename, format = 'pdf', pad_inches=cm2inch(0.1) ) #, bbox_inches='tight') #)

def plotmultimap(m, nrowcol, filename, title=None, vmin=None, vmax=None,
                 units='', cbar=True, mask=None, ctab='parchment',
                 width=18.0):
    '''Plot multiple maps in a single figure with common colourbar.'''
    
    nside = hp.npix2nside(len(m[0]))

    if ctab == 'parchment':
        cmap = planck_parchment_cmap
    elif ctab == 'grey':
        cmap = planck_grey_cmap
    else:
        cmap = cm.binary

    # using directly matplotlib instead of mollview has higher
    # quality output, I plan to merge this into healpy

    # ratio is always 1/2
    xsize = 2000
    ysize = xsize/2.0

    theta = np.linspace(np.pi, 0, ysize)
    phi = np.linspace(-np.pi, np.pi, xsize)
    longitude = np.radians(np.linspace(-180, 180, xsize))
    latitude = np.radians(np.linspace(-90, 90, ysize))

    # project the map to a rectangular matrix xsize x ysize
    PHI, THETA = np.meshgrid(phi, theta)
    grid_pix = hp.ang2pix(nside, THETA, PHI)

    from matplotlib.projections.geo import GeoAxes

    class ThetaFormatterShiftPi(GeoAxes.ThetaFormatter):
        """Shifts labelling by pi

        Shifts labelling from -180,180 to 0-360"""
        def __call__(self, x, pos=None):
            if x != 0:
                x *= -1
            if x < 0:
                x += 2*np.pi
            return GeoAxes.ThetaFormatter.__call__(self, x, pos)

    nrow, ncol = nrowcol
    rat = float(nrow)/float(ncol)

    height = 0.6 * width * rat
    fig = plt.figure(figsize=(cm2inch(width), cm2inch(height)))

    for i, s in enumerate(m):
        if mask != None:
            s = np.ma.masked_array(s, np.logical_not(mask))
            grid_mask = s.mask[grid_pix]
            grid_map = np.ma.MaskedArray(s[grid_pix], grid_mask)
        else:
            grid_map = s[grid_pix]

        # matplotlib is doing the mollweide projection
        ax = plt.subplot(nrow, ncol, i+1, projection='mollweide')
        # rasterized makes the map bitmap while the labels remain vectorial
        # flip longitude to the astro convention
        image = plt.pcolormesh(longitude[::-1], latitude, grid_map, vmin=vmin,
                               vmax=vmax, rasterized=True, cmap=cmap)
        # Title of map
        if title != None:
            plt.title(title[i], fontsize='small')
        # remove tick labels
        ax.xaxis.set_ticklabels([])
        ax.yaxis.set_ticklabels([])
        # remove grid
        ax.xaxis.set_ticks([])
        ax.yaxis.set_ticks([])

    if cbar:
        # colorbar
        cax = fig.add_axes([0.35, 0.08, 0.3, 0.04*0.5/rat])
        cb = fig.colorbar(image, cax=cax, orientation='horizontal', ticks=[vmin, vmax])
        cb.ax.xaxis.set_label_text(units)
        cb.ax.xaxis.labelpad = -8
        # workaround for issue with viewers, see colorbar docstring
        cb.solids.set_edgecolor('face')

    plt.subplots_adjust(left=0.0, right=1.0, bottom=0.1, top=1.0, wspace=0.02, hspace=0.01)

    plt.savefig(filename, bbox_inches='tight', pad_inches=cm2inch(0.1))

def colourbar(vmin, vmax, filename, units='', ctab='parchment'):

    width = 6.0
    height = 2.0

    fig = plt.figure(figsize=(cm2inch(width), cm2inch(height)))
    ax = fig.add_axes([0.05, 0.8, 0.9, 0.15])
    
    if ctab == 'parchment':
        cmap = planck_parchment_cmap
    elif ctab == 'grey':
        cmap = planck_grey_cmap
    else:
        cmap = cm.binary

    norm = mpl.colors.Normalize(vmin=vmin, vmax=vmax)
    cb = mpl.colorbar.ColorbarBase(ax, cmap=cmap, norm=norm,
        orientation='horizontal', ticks=[vmin, vmax],fontsize=8)
    cb.set_label(units)
    cb.ax.xaxis.labelpad = -8
    # workaround for issue with viewers, see colorbar docstring
    cb.solids.set_edgecolor("face")
    
    plt.savefig(filename, bbox_inches='tight', pad_inches=cm2inch(0.1))


m = hp.read_map("../dust_peaks.fits")
plotmap(m, "peaks.pdf",title=r"peak with $e>0.6,\ I>0.5\sigma_I$", vmin=1.e-8, vmax=1., units='K',
            cbar=False, mask=None, ctab='', width=20., grat=True)
