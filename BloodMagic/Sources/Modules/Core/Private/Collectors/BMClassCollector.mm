//
// Created by Alex Denisov on 12.07.13.
// Copyright (c) 2013 railsware. All rights reserved.
//

#import <objc/runtime.h>
#import "BMClassCollector.h"

@implementation BMClassCollector
{
    class_list_t _cachedClasses;
    class_list_map_t _cachedClassesMap;
}

+ (instancetype)collector
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    [self collectClasses];
    
    return self;
}

- (void)dealloc
{
    for (auto it = _cachedClassesMap.cbegin(); it != _cachedClassesMap.cend();) {
        class_list_map_t::iterator removeIt = _cachedClassesMap.erase(it++);
        delete (*removeIt).second;
    }
}

- (void)collectClasses
{
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
    uint classesCount;

    uint imagesCount;
    const char **imagesNames = objc_copyImageNames(&imagesCount);
    Class nsobjectClass = NSClassFromString(@"NSObject");
    for (uint imageIndex = 0; imageIndex < imagesCount; imageIndex++) {
        const char* imageName = imagesNames[imageIndex];
        const char **classNames = objc_copyClassNamesForImage(imageName, &classesCount);
        for (uint classIndex = 0; classIndex < classesCount; classIndex++) {
            Class nextClass = objc_getClass(classNames[classIndex]);

            Class superClass = nextClass;
            do
            {
                superClass = class_getSuperclass(superClass);
            } while(superClass && superClass != nsobjectClass);

            if (superClass == nil)
            {
                continue;
            }
            _cachedClasses.push_back(nextClass);
        }
        free(classNames);
    }
    free(imagesNames);
#else
    Class parentClass = [NSObject class];
    int numClasses = objc_getClassList(NULL, 0);
   
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvla-extension"
    Class classes[sizeof(Class) * numClasses];
#pragma clang diagnostic pop   
   
    numClasses = objc_getClassList(classes, numClasses);
    for (NSInteger i = 0; i < numClasses; i++) {
        Class superClass = classes[i];
        do {
            superClass = class_getSuperclass(superClass);
        } while (superClass && superClass != parentClass);

        if (superClass == nil) {
            continue;
        }

        Class klass = classes[i];

        if (class_getName(klass)[0] == '_') {
            continue;
        }
        _cachedClasses.push_back(klass);
    }
#endif
}

- (class_list_t *)collectForProtocol:(Protocol *)protocol
{
    NSUInteger protocolKey = (NSUInteger)protocol;

    class_list_t *classes = _cachedClassesMap[protocolKey];

    if (classes && classes->size()) {
        return classes;
    }
    classes = new class_list_t;

    for (auto it = _cachedClasses.cbegin(); it != _cachedClasses.cend(); it++ ) {
        Class klass = *it;
        if ([klass conformsToProtocol:protocol]) {
            classes->push_back(klass);
        }
    }

    _cachedClassesMap[protocolKey] = classes;
    
    return classes;
}

@end
