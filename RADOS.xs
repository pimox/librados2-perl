#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <rados/librados.h>

#define DEBUG_RADOS 0

#define DPRINTF(fmt, ...)\
	do { if (DEBUG_RADOS) { printf("debug: " fmt, ## __VA_ARGS__); } } while (0)

MODULE = PVE::RADOS		PACKAGE = PVE::RADOS

rados_t
pve_rados_create(user)
SV *user
PROTOTYPE: $
CODE:
{
    char *u = NULL;
    rados_t clu = NULL;

    if (SvOK(user)) {
	u = SvPV_nolen(user);
    }

    int ret = rados_create(&clu, u);

    if (ret == 0)
        RETVAL = clu;
    else {
        die("rados_create failed - %s\n", strerror(-ret));
        RETVAL = NULL;
    }
}
OUTPUT: RETVAL

void
pve_rados_conf_set(cluster, key, value)
rados_t cluster
char *key
char *value
PROTOTYPE: $$$
CODE:
{
    DPRINTF("pve_rados_conf_set %s = %s\n", key, value);

    int res = rados_conf_set(cluster, key, value);
    if (res < 0) {
        die("rados_conf_set failed - %s\n", strerror(-res));
    }
}

void
pve_rados_conf_read_file(cluster, path)
rados_t cluster
SV *path
PROTOTYPE: $$
CODE:
{
    char *p = NULL;

    if (SvOK(path)) {
	p = SvPV_nolen(path);
    }

    DPRINTF("pve_rados_conf_read_file %s\n", p);

    int res = rados_conf_read_file(cluster, p);
    if (res < 0) {
        die("rados_conf_read_file failed - %s\n", strerror(-res));
    }
}

void
pve_rados_connect(cluster)
rados_t cluster
PROTOTYPE: $
CODE:
{
    DPRINTF("pve_rados_connect\n");

    int res = rados_connect(cluster);
    if (res < 0) {
        die("rados_connect failed - %s\n", strerror(-res));
    }
}

void
pve_rados_shutdown(cluster)
rados_t cluster
PROTOTYPE: $
CODE:
{
    DPRINTF("pve_rados_shutdown");
    rados_shutdown(cluster);
}

SV *
pve_rados_mon_command(cluster, cmds)
rados_t cluster
AV *cmds
PROTOTYPE: $$
CODE:
{
    const char *cmd[64];
    size_t cmdlen = 0;

    char *outbuf =NULL;
    size_t outbuflen = 0;
    char *outs = NULL;
    size_t outslen = 0;

    SV *arg;

    while ((arg = av_pop(cmds)) && (arg != &PL_sv_undef)) {
        if (cmdlen >= 63) {
            die("too many arguments");
        }
        cmd[cmdlen] = SvPV_nolen(arg);
        DPRINTF("pve_rados_mon_command%zd %s\n", cmdlen, cmd[cmdlen]);
        cmdlen++;
    }

    int ret = rados_mon_command(cluster, cmd, cmdlen,
                                NULL, 0,
                                &outbuf, &outbuflen,
                                &outs, &outslen);

    if (ret < 0) {
        char msg[4096];
        if (outslen > sizeof(msg)) {
            outslen = sizeof(msg);
        }
        snprintf(msg, sizeof(msg), "mon_command failed - %.*s\n", (int)outslen, outs);
        rados_buffer_free(outs);
        if (outbuf != NULL) {
            rados_buffer_free(outbuf);
        }
        die(msg);
    }

    RETVAL = newSVpv(outbuf, outbuflen);

    rados_buffer_free(outbuf);
}
OUTPUT: RETVAL

HV *
pve_rados_cluster_stat(cluster)
rados_t cluster
PROTOTYPE: $
CODE:
{
    struct rados_cluster_stat_t result;

    DPRINTF("pve_rados_cluster_stat");

    int ret = rados_cluster_stat(cluster, &result);

    if(ret != 0) {
        warn("rados_cluster_stat failed (ret=%d)\n", ret);
        XSRETURN_UNDEF;
    }
    HV * rh = (HV *)sv_2mortal((SV *)newHV());

    (void)hv_store(rh, "kb", 2, newSViv(result.kb), 0);
    (void)hv_store(rh, "kb_used", 7, newSViv(result.kb_used), 0);
    (void)hv_store(rh, "kb_avail", 8, newSViv(result.kb_avail), 0);
    (void)hv_store(rh, "num_objects", 11, newSViv(result.num_objects), 0);

    RETVAL = rh;
}
OUTPUT: RETVAL
