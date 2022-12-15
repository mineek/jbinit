#ifndef support_h
#define support_h

CFOptionFlags showMessage(CFDictionaryRef dict);
void showSimpleMessage(NSString *title, NSString *message);
int run(const char *cmd, char * const *args);

#endif /* support_h */
