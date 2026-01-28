//SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (c) 2019 MediaTek Inc.
 */

#include "../../drivers/misc/mediatek/base/power/include/mtk_upower.h"

static unsigned int get_next_freq(struct sugov_policy *sg_policy,
                  unsigned long util, unsigned long max)
{
    struct cpufreq_policy *policy = sg_policy->policy;
    int idx, target_idx = 0;
    int cap;
    int cpu = policy->cpu;
    struct upower_tbl *tbl;

    /* CUSTOM: SMART FALLBACK
     * Default to current frequency to maintain stability if table lookup fails.
     */
    unsigned int freq = policy->cur;

    /* CUSTOM: 5% EFFICIENCY MARGIN (Overflow Protected)
     * We cast to u64 to ensure the multiplication never overflows, 
     * even if 'util' spikes unexpectedly high.
     * 1024 = 100%. 1075 = 105%.
     */
    util = (unsigned long)((unsigned long long)util * 1075 / SCHED_CAPACITY_SCALE);

    tbl = upower_get_core_tbl(cpu);

    /* Safety Check: If table is missing, use the 'freq' fallback defined above */
    if (unlikely(!tbl))
        goto out;

    for (idx = 0; idx < tbl->row_num ; idx++) {
        cap = tbl->row[idx].cap;
        
        if (!cap)
            break;

        target_idx = idx;

        /* OPTIMIZED: Use '>=' to catch exact matches (Saves Battery) */
        if (cap >= util)
            break;
    }

    freq = mt_cpufreq_get_cpu_freq(cpu, target_idx);

out:
    sg_policy->cached_raw_freq = freq;
    return cpufreq_driver_resolve_freq(policy, freq);
}