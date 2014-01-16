#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <rados/librados.h>

MODULE = PVE::RADOS		PACKAGE = PVE::RADOS

rados_t 
pve_rados_create() 
PROTOTYPE:
CODE:
{	
    rados_t clu = NULL;	 
    int ret = rados_create(&clu, NULL);
    
    if (ret == 0)
        RETVAL = clu;
    else {
        warn("rados_create failed (ret=%d)\n", ret);
        RETVAL = NULL;
    }
}
OUTPUT: RETVAL

int 
pve_rados_conf_set(cluster, key, value) 
rados_t cluster
char *key
char *value
PROTOTYPE: $$$
CODE:
{
    RETVAL = rados_conf_set(cluster, key, value);
    if (RETVAL < 0) {		 
        die("rados_conf_set failed - %s\n", strerror(-RETVAL));
    }	 
}
OUTPUT: RETVAL


int pve_rados_connect(cluster) 
rados_t cluster
PROTOTYPE: $
CODE:
{
    rados_conf_read_file(cluster, NULL);
 
    RETVAL = rados_connect(cluster);
    if (RETVAL < 0) {
        die("rados_connect failed - %s\n", strerror(-RETVAL));
    }
}
OUTPUT: RETVAL

void
pve_rados_shutdown(cluster) 
rados_t cluster
PROTOTYPE: $
CODE:
{
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
        cmdlen++;
    } 

    int ret = rados_mon_command(cluster, cmd, cmdlen,
                                NULL, 0,
                                &outbuf, &outbuflen,
                                &outs, &outslen);

    if (ret < 0) {
        die("mon_command failed - %s\n", outs);
        rados_buffer_free(outs);
    }
 
    printf("TEST %d %d %d\n", ret, outbuflen, outslen);

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
    int ret = rados_cluster_stat(cluster, &result);
  
    if(ret != 0) {
        warn("rados_cluster_stat failed (ret=%d)\n", ret);
        XSRETURN_UNDEF;
    }
    HV * rh = (HV *)sv_2mortal((SV *)newHV());

    hv_store(rh, "kb", 2, newSViv(result.kb), 0);
    hv_store(rh, "kb_used", 7, newSViv(result.kb_used), 0);
    hv_store(rh, "kb_avail", 8, newSViv(result.kb_avail), 0);
    hv_store(rh, "num_objects", 11, newSViv(result.num_objects), 0);

    RETVAL = rh;
}
OUTPUT: RETVAL
