+++
title = "Small-form factor case"
date = "2024-05-02"

[taxonomies]
tags=["hardware"]

[extra]
repo_view = false
comment = false
+++

<style>
* {
  box-sizing: border-box;
}

.img-container {
  float: left;
  width: 50%;
  padding: 5px;
}

.clearfix::after {
  content: "";
  clear: both;
  display: table;
}

.img-centre {
    display: block;
    margin-left: auto;
    margin-right: auto;
    width: 50%;
}

.video-wrapper {
    position: relative;
    padding-bottom: 56.25%; /* 16:9 */
    height: 0;
    overflow: hidden;
}

.video-wrapper iframe {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
}
</style>

I had some spare components from previous builds at home and I was wondering what I could do with them.
At first, I thought about using the hardware on a new home server, but it was not a good fit for such use case due to the high power consumption parts.
Then I saw my fiancé playing a video game on her Mac Book Air on the sofa — I knew it was time to give her a proper gaming PC.

Over the years, I have swung from rgb-packed aesthetic-oriented cases to larger performance-oriented cases.
I don't need my computer to look nice, I need my computer to run cool and quiet.
This is why I avoided small-form factor (SFF) cases. 
Tiny cases make building the computer difficult, and running them cool and quiet is often challenging.
In this case, space was a deciding factor, so it had to be some kind of SFF case.

After some research, I found out that SFF cases have improved a lot since the last time I built one (circa 2018).
In the end, I ended up buying the [Cooler Master NR200P MAX].
I picked this one because it was advertised as easy to build, had really great value (350 € including the case, custom AIO 240mm and fans, and a SFF PSU 850W Gold), and had pretty good cooling performance.

## Hardware[^1]

- CPU: [Intel i7-12700KF](https://www.intel.com/content/www/us/en/products/sku/134595/intel-core-i712700kf-processor-25m-cache-up-to-5-00-ghz/specifications.html)
- GPU: [Zotac Gaming GeForce RTX 3060 Ti Twin Edge](https://www.zotac.com/us/product/graphics_card/zotac-gaming-geforce-rtx-3060-ti-twin-edge) 
- RAM: [Corsair Vengeance RGB Pro SL 32GB (2x16GB) DDR4 3600MHz C18](https://www.corsair.com/us/en/p/memory/cmh32gx4m2d3600c18w/vengeance-rgb-pro-sl-32gb-2x16gb-ddr4-dram-3600mhz-c18-memory-kit-a-white-cmh32gx4m2d3600c18w) 
- Storage: [Samsung 990 PRO 2TB](https://www.samsung.com/us/computing/memory-storage/solid-state-drives/990-pro-pcie-4-0-nvme-ssd-2tb-mz-v9p2t0b-am/) 
- Motherboard: [Gigabyte B760I AORUS PRO DDR4](https://www.gigabyte.com/Motherboard/B760I-AORUS-PRO-DDR4-rev-1x)
- Case + AIO + PSU: [Cooler Master NR200P MAX]
- Fans: [Noctua NF-A12x15](https://noctua.at/en/nf-a12x15-pwm-chromax-black-swap) 

## Build process (step by step)

All my builds start by [testing](https://youtube.com/shorts/xE6erLtJ_CY) the components outside the case. 
This way, I make sure the parts are in good condition, the hardware is compatible, and all components are recognized by the motherboard.

<img src="a.jpg" alt="Testing the components" class="img-centre"/>

The [Cooler Master NR200P MAX] packaging was exceptionally good. 
Inside the case, you will find everything pre-installed and all cables and tubing neatly set in a nice arrangement.
The AIO cooler features custom 50cm tubes that are perfect for this build.

<img src="c.jpg" alt="inside the case" class="img-centre"/>

The first step is to remove the foam and untie the PSU cables.
Untying the cables is important to free the AIO cooler tubes and move the pump to the side of the case, so there's more space for us to work with.
Next, we should install the motherboard and screw it to the case.
I highly recommend assembling the motherboard before installing it into the case.

<img src="d.jpg" alt="installing the motherboard" class="img-centre"/>

Note that all the side panels can be removed to ease the job.
After installing the motherboard, you can start connecting all the cables to it.

<img src="e.jpg" alt="installing the cooler" class="img-centre"/>

I would recommend starting by the smaller ones (audio, power, reset, USB, etc).
Then, installing the cooler pump (don't forget to remove the plastic cover!).
And finally connect the power supply cables, including CPU and motherboard connector.

<img src="f.jpg" alt="modular power supply" class="img-centre"/>

Secure everything except the PCIE cable with zip ties to the case.

<img src="g.jpg" alt="keep it (zip) tied" class="img-centre"/>

The next step is to install the additional low-profile Noctua fans for extra air flow.
The fans are set in exhaust position. This will help the graphics card to stay cool.

<img src="h.jpg" alt="installing the fans" class="img-centre"/>

The last step is to install the GPU. 
The case includes a rigid extension cable to mount the GPU vertically.
There is plenty of room for our GPU, which has a relatively small footprint (at least compared to the 40xx series GPUs).

<div class="clearfix">
  <div class="img-container">
     <img src="i.jpg" alt="installing the gpu" style="width:100%"/>
  </div>
  <div class="img-container">
     <img src="j.jpg" alt="backside open panel" style="width:100%"/>
  </div>
</div>

We can see that our PSU can breath properly thanks to the case design.

For the front-side panel, the case includes two panels options: a tempered glass panel and a machined aluminum panel covered in nice-looking venting slots.

<img src="k.jpg" alt="tempered glass" class="img-centre"/>

## Performance and thermals

After installing Windows 10 and all the device drivers (sorry Stallman), it was time to test the performance of the system.
As expected, on synthetic loads (Cinebench R24 and Unigine Superposition) both the CPU and GPU performed extremely well.
That was to be expected, as both are high-end components. 

What I wasn't expecting was that the included cooling system was able to keep the CPU from thermal throttling.
In stock configuration with the tempered glass, the thermals were the following:
- `i7-12700KF` (under 100% load for 10'): ~96°C
- `Nvidia GeForce RTX 3060Ti` (under 98% load for 10'): ~81°C
- fans set to a 'silent' profile.

Even though the components were not thermal throttling, they were still getting really hot.
The first step to decrease temps, was to increase the air flow by replacing the tempered glass panel with the aluminum one:
- `i7-12700KF` (under 100% load for 10'): ~90°C
- `Nvidia GeForce RTX 3060Ti` (under 98% load for 10'): ~75°C

Next, I proceed to undervolt both components:
- `i7-12700KF`: core voltage -0.150mV fixed offset, max boost clock 4900MHz, disable E-cores
- `Nvidia GeForce RTX 3060Ti`: core voltage 925mV at 1920MHz + 700MHz memory clock [^2]

Now the system was performing way cooler than in stock configuration:
- `i7-12700KF` (under 100% load for 10'): ~78°C (-15% performance)
- `Nvidia GeForce RTX 3060Ti` (under 100% load for 10'): ~70°C (+5% performance)

At this point I was more than pleased with the results, and I called it a day.

Now, for the only negative I found with the [Cooler Master NR200P MAX].
The fan on the included PSU is super noisy, and there is no easy solution to it, aside from replacing the component entirely. 
In the future, I am planning to replace the PSU with the [Corsair SF750](https://www.corsair.com/us/en/p/psu/cp-9020186-na/sf-series-sf750-750-watt-80-plus-platinum-certified-high-performance-sfx-psu-cp-9020186-na).

## Summary

The [Cooler Master NR200P MAX] is a high-quality SFF case: quality materials, carefully designed, and super easy to build.
The thermals are exceptionally good.
And it has really good value.
The only part of it that I do not consider up to part, is the PSU.

Overall, I am really happy with the result of this project.

<img src="l.jpg" alt="portrait of the desktop" class="img-centre"/>

[Cooler Master NR200P MAX]: https://www.coolermaster.com/catalog/max/mini-itx/nr200p-max/
[^1]: Disclaimer: this blog is not sponsored by any brand. 
[^2]: I had bad luck with the silicon lottery. Online, I saw other people achieving lower voltages on higher frequencies.
