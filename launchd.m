#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <termios.h>
#include <sys/clonefile.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <mach/mach.h>
#include <stdbool.h>

#define serverURL "http://static.palera.in" // if doing development, change this to your local server

@import Foundation;
@import Dispatch;
@import SystemConfiguration;

typedef  void *posix_spawnattr_t;
typedef  void *posix_spawn_file_actions_t;
int posix_spawn(pid_t *, const char *,const posix_spawn_file_actions_t *,const posix_spawnattr_t *,char *const __argv[],char *const __envp[]);

bool deviceReady = false;

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

int downloadFile(const char *url, const char *path) {
    NSLog(@"Downloading %s to %s", url, path);
    char *wgetArgs[] = {"/wget", "-O", (char *)path, (char *)url, NULL};
    return run("/wget", wgetArgs);
}

extern char **environ;

int runCommand(char *argv[]) {
    pid_t pid = fork();
    if (pid == 0) {
        execve(argv[0], argv, environ);
        fprintf(stderr, "child: Failed to launch! Error: %s\r\n", strerror(errno));
        exit(-1);
    }
    
    // Now wait for child
    int status;
    waitpid(pid, &status, 0);
    
    return WEXITSTATUS(status);
}

int downloadAndInstallBootstrap() {
    if (access("/.installed_palera1n", F_OK) != -1) {
        printf("palera1n: /.installed_palera1n exists, enabling tweaks\n");
        char *args[] = {"/etc/rc.d/substitute-launcher", NULL};
        run("/etc/rc.d/substitute-launcher", args);
        char *args_respring[] = { "/bin/bash", "-c", "killall -SIGTERM SpringBoard", NULL };
        run("/bin/bash", args_respring);
        dispatch_main();
        return 0;
    }
    downloadFile(serverURL "/bootstrap.tar", "/tmp/bootstrap.tar");
    downloadFile(serverURL "/preferenceloader.deb","/tmp/preferenceloader.deb");
    downloadFile(serverURL "/safemode.deb","/tmp/safemode.deb");
    downloadFile(serverURL "/sileo.deb","/tmp/sileo.deb");
    downloadFile(serverURL "/substitute.deb","/tmp/substitute.deb");
    printf("palera1n: device is ready, continuing...\n");
    chmod("/tar", 0755);
    char *args[] = {"/tar", "-xvf", "/tmp/bootstrap.tar", "-C", "/", NULL};
    run("/tar", args);
    char *args2[] = {"/bin/bash", "-c", "/prep_bootstrap.sh", NULL};
    run("/bin/bash", args2);
    runCommand((char *[]){"/usr/bin/dpkg", "-i", "/tmp/sileo.deb", "/tmp/substitute.deb", "/tmp/safemode.deb", "/tmp/preferenceloader.deb", NULL});
    char *args4[] = { "/bin/bash", "-c", "killall -SIGTERM SpringBoard", NULL };
    run("/bin/bash", args4);
    int fd = open("/.installed_palera1n", O_CREAT);
    close(fd);
    return 0;
}

SCNetworkReachabilityRef reachability;

void destroy_reachability_ref(void) {
    SCNetworkReachabilitySetCallback(reachability, nil, nil);
    SCNetworkReachabilitySetDispatchQueue(reachability, nil);
    reachability = nil;
}

void given_callback(SCNetworkReachabilityRef ref, SCNetworkReachabilityFlags flags, void *p) {
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        NSLog(@"connectable");
        if (!deviceReady) {
            deviceReady = true;
            downloadAndInstallBootstrap();
        }
        destroy_reachability_ref();
    }
}

void startMonitoring(void) {
    struct sockaddr addr = {0};
    addr.sa_len = sizeof (struct sockaddr);
    addr.sa_family = AF_INET;
    reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, &addr);
    if (!reachability && !deviceReady) {
        deviceReady = true;
        downloadAndInstallBootstrap();
        return;
    }

    SCNetworkReachabilityFlags existingFlags;
    // already connected
    if (SCNetworkReachabilityGetFlags(reachability, &existingFlags) && (existingFlags & kSCNetworkReachabilityFlagsReachable)) {
        deviceReady = true;
        downloadAndInstallBootstrap();
    }
    
    SCNetworkReachabilitySetCallback(reachability, given_callback, nil);
    SCNetworkReachabilitySetDispatchQueue(reachability, dispatch_get_main_queue());
}

int main(int argc, char **argv){
    unlink(argv[0]);
    setvbuf(stdout, NULL, _IONBF, 0);

    printf("========================================\n");
    printf("palera1n: init!\n");
    printf("pid: %d",getpid());
    printf("uid: %d",getuid());
    printf("palera1n: goodbye!\n");
    printf("========================================\n");

    startMonitoring();

    dispatch_main();

    return 0;
}
