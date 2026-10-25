# Post-restore storage measurement and proposed beginner package

## One measurement session, not a performance qualification

Measured on 25 October 2026 on the restored Mac mini M4 (Mac16,10), 24 GB RAM. The owner confirms that the installed 2 TB replacement module was purchased from [Expand Mac mini](https://expandmacmini.com/products/ssd-m4). macOS reports the internal storage as APPLE SSD AP2048Z, capacity 2,001,111,162,880 bytes. That model string does not establish who manufactured the replacement PCB or NAND.

There was **one sequential write round and one sequential read round per disk**, in a single session. No repetitions or statistical confidence estimates were performed. These are subsequent storage measurements, not a new restore test or evidence that the generalized restore source works on another device.

| Storage | Filesystem | Bytes per write/read | Write seconds | Write MB/s | Read seconds | Read MB/s |
|---|---|---:|---:|---:|---:|---:|
| Internal 2 TB replacement module | APFS | 2,147,483,648 | 0.914514208 | 2348.2 | 0.808357791 | 2656.6 |
| External Samsung PM981a NVMe 1 TB | exFAT | 2,147,483,648 | 1.495658417 | 1435.8 | 0.658349209 | 3261.9 |
| External Samsung 990 PRO 4 TB in TREBLEET enclosure | exFAT | 2,147,483,648 | 0.776995667 | 2763.8 | 0.642339500 | 3343.2 |

MB/s means 1,000,000 bytes per second. Tests ran sequentially, one disk at a time, using unique, exclusively created files and 8 MiB blocks. The internal test directory was on the local APFS Data filesystem, not a NAS or cloud mount. A randomly generated 8 MiB buffer was reused through each file.

The macOS SDK header confirmed F_NOCACHE = 48. Setting fcntl(fd, F_NOCACHE, 1) returned zero for both write and read descriptors on all three disks. Timing used a monotonic clock. Write timing included fsync. Each read completed the expected byte count; the final block was checked against the write buffer. Only test files and their empty unique directories were removed, and removal was verified.

The external PM981a reported PCIe x4 at 8.0 GT/s. The 990 PRO reported PCIe x4 at 16.0 GT/s; its TREBLEET enclosure negotiated USB4 at 40 Gbit/s on this Mac. The internal SSD reported Apple Fabric, without a comparable PCIe link speed.

**Limits:** these very short 2 GiB measurements do not establish peak specifications, sustained performance after SSD cache exhaustion, random I/O, NAS speed, reliability, or relative superiority of an external SSD over the internal storage. F_NOCACHE disables macOS file-data caching for the descriptors, not the SSD's own cache. Background load, thermal conditions, filesystem and test design can affect results. The tests were not repeated.

## User-requested product direction: a guided Windows package

The owner's intended end product is a simple downloadable Windows package for people without technical experience, accompanied by a comprehensive explanation and troubleshooting guide.

**This is a product requirement, not a claim that such a plug-and-play package already exists.** The successful archived executable was restricted to the owner's device. The generalized evaluation source has not yet completed a physical restore on another Mac.

The first supported target should be explicit: **Mac mini M4, Mac16,10**, with a validated compatible replacement storage module and an explicitly supported restore image. The physical success currently documented is one Mac with the owner's Expand Mac mini 2 TB module. Other compatible storage capacities or suppliers may work, but that remains a hypothesis until individually validated. Generic PC NVMe drives are not automatically interchangeable with the Mac's proprietary storage module.

A beginner package should:
- Identify the connected Mac and enforce a validated model/firmware policy, stopping on an unknown or ambiguous target.
- Guide the user through cable, port, power and DFU steps, showing current progress in plain language.
- Check prerequisites and firmware integrity, using a defined, properly distributed driver approach without disabling Windows protections.
- Clearly explain that Restore erases the target Mac, require the user's explicit confirmation, and leave credentials and Activation Lock to the owner.
- Handle USB-mode transitions, failures and retries; clean up its own temporary changes; retain a readable diagnostic report without secrets.
- Include a short start guide plus the full technical explanation, known limits, recovery steps and upstream licensing notices.
- Be tested on additional Windows computers and physical Macs before being advertised as a general consumer solution.

No new restore, driver installation, public release, repository visibility change or supplier access is authorized or performed by this documentation update.
