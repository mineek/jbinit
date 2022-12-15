#include "CFUserNotification.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CFNetwork/CFNetwork.h>
#import <dispatch/dispatch.h>
#import <notify.h>

#import "support.h"

typedef  void *posix_spawnattr_t;
typedef  void *posix_spawn_file_actions_t;
int posix_spawn(pid_t *, const char *,const posix_spawn_file_actions_t *,const posix_spawnattr_t *,char *const __argv[],char *const __envp[]);

CFOptionFlags showMessage(CFDictionaryRef dict) {
    while (true) {
        SInt32 err = 0;
        CFUserNotificationRef notif = CFUserNotificationCreate(NULL, 0, kCFUserNotificationPlainAlertLevel, &err, dict);
        if (notif == NULL || err != 0) {
            sleep(1);
            continue;
        }
        
        CFOptionFlags response = 0;
        CFUserNotificationReceiveResponse(notif, 0, &response);
        
        sleep(1);
        
        if ((response & 0x3) != kCFUserNotificationCancelResponse) {
            return response & 0x3;
        }
    }
}

void showSimpleMessage(NSString *title, NSString *message) {
    CFDictionaryRef dict = (__bridge CFDictionaryRef) @{
        (__bridge NSString*) kCFUserNotificationAlertTopMostKey: @1,
        (__bridge NSString*) kCFUserNotificationAlertHeaderKey: title,
        (__bridge NSString*) kCFUserNotificationAlertMessageKey: message
    };
    
    showMessage(dict);
}

int run(const char *cmd, char * const *args){
    int pid = 0;
    int retval = 0;
    char printbuf[0x1000] = {};
    for (char * const *a = args; *a; a++) {
        size_t csize = strlen(printbuf);
        if (csize >= sizeof(printbuf)) break;
        snprintf(printbuf+csize,sizeof(printbuf)-csize, "%s ",*a);
    }

    retval = posix_spawn(&pid, cmd, NULL, NULL, args, NULL);
    printf("Execting: %s (posix_spawn returned: %d)\n",printbuf,retval);
    {
        int pidret = 0;
        printf("waiting for '%s' to finish...\n",printbuf);
        retval = waitpid(pid, &pidret, 0);
        printf("waitpid for '%s' returned: %d\n",printbuf,retval);
        return pidret;
    }
    return retval;
}