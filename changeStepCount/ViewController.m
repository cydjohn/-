//
//  ViewController.m
//  changeStepCount
//
//  Created by yudong cao on 4/3/18.
//  Copyright © 2018 Yudong Cao. All rights reserved.
//

#import "ViewController.h"
#import <HealthKit/HealthKit.h>

@interface ViewController () <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *stepCountValueLabel;
@property (weak, nonatomic) IBOutlet UITextField *stepsTextField;
@property (nonatomic) HKHealthStore *healthStore;
@end



@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.stepsTextField.delegate = self;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resignTextFiledFirstResponse)];
    [self.view addGestureRecognizer:tap];
    
}

- (void) resignTextFiledFirstResponse {
    [self.stepsTextField resignFirstResponder];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)changeButton:(id)sender {
    [self saveStepCountIntoHealthStore:[self.stepsTextField.text doubleValue]];
    [self.stepsTextField resignFirstResponder];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Set up an HKHealthStore, asking the user for read/write permissions. The profile view controller is the
    // first view controller that's shown to the user, so we'll ask for all of the desired HealthKit permissions now.
    // In your own app, you should consider requesting permissions the first time a user wants to interact with
    // HealthKit data.
    if ([HKHealthStore isHealthDataAvailable]) {
        NSSet *writeDataTypes = [self dataTypesToWrite];
        NSSet *readDataTypes = [self dataTypesToRead];
        
        [self.healthStore requestAuthorizationToShareTypes:writeDataTypes readTypes:readDataTypes completion:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"You didn't allow HealthKit to access these read/write data types. In your app, try to handle this error gracefully when a user decides not to provide access. The error was: %@. If you're using a simulator, try it on a device.", error);
                
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Update the user interface based on the current user's health information.
                [self updateStepCountLabel];
            });
        }];
    }
}

#pragma mark - HealthKit Permissions

// Returns the types of data that Fit wishes to write to HealthKit.
// 写入数据
- (NSSet *)dataTypesToWrite
{
    HKQuantityType *stepCountType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount]; // 步数
    
    return [NSSet setWithObjects: stepCountType, nil];
}

// Returns the types of data that Fit wishes to read from HealthKit.
// 读取数据
- (NSSet *)dataTypesToRead
{
    
    HKQuantityType *stepCountType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount]; // 步数
    
    return [NSSet setWithObjects: stepCountType, nil];
}


- (void)updateStepCountLabel
{
//    self.stepCountUnitLabel.text = @"步数 (健康+App步)";
    self.stepCountValueLabel.text = @"0";
    
    HKQuantityType *stepCountType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    //NSSortDescriptors用来告诉healthStore怎么样将结果排序。
    NSSortDescriptor *start = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierStartDate ascending:NO];
    NSSortDescriptor *end = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierEndDate ascending:NO];
    // 当天时间段
    NSPredicate *todayPredicate = [self predicateForSamplesToday];
    HKSampleQuery *sampleQuery = [[HKSampleQuery alloc] initWithSampleType:stepCountType predicate:todayPredicate limit:HKObjectQueryNoLimit sortDescriptors:@[start, end] resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
        //打印查询结果
        NSLog(@"resultCount = %ld result = %@",results.count,results);
        double deviceStepCounts = 0.f;
        double appStepCounts = 0.f;
        for (HKQuantitySample *result in results) {
            HKQuantity *quantity = result.quantity;
            HKUnit *stepCount = [HKUnit countUnit];
            double count = [quantity doubleValueForUnit:stepCount];
            // 实例数据
            //            "50 count \"Fit\" (1) 2016-07-11 17:43:03 +0800 2016-07-11 17:43:03 +0800",
            //            "26 count \"你的设备名\" (9.3.1) \"iPhone\" 2016-07-11 15:19:33 +0800 2016-07-11 15:19:41 +0800",
            
            //            26：result.quantity
            //            count：单位，还有其它kg、m等，不同单位使用不同HKUnit
            //            \"Fit\"：result.source.name
            //            (9.3.1)：result.device.softwareVersion，App写入的时候是空的
            //            \"iPhone\"：result.device.model
            //            2016-07-11 15:19:33 +0800：result.startDate
            //            2016-07-11 15:19:41 +0800：result.endDate
            
            
            // 区分手机自动计算步数和App写入的步数
            if ([result.source.name isEqualToString:[UIDevice currentDevice].name]) {
                // App写入的数据result.device.name为空
                if (result.device.name.length > 0) {
                    deviceStepCounts += count;
                }
                else {
                    appStepCounts += count;
                }
            }
            else {
                appStepCounts += count;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{

            NSString *totalCountsString = [NSNumberFormatter localizedStringFromNumber:@(deviceStepCounts+appStepCounts) numberStyle:NSNumberFormatterNoStyle];
            
            NSString *text = [NSString stringWithFormat:@"设备步数为: %d,app步数为: %d, 总步数为: %@", (int)deviceStepCounts,(int)appStepCounts,totalCountsString];
            self.stepCountValueLabel.text = text;
        });
        
    }];
    //执行查询
    [self.healthStore executeQuery:sampleQuery];
}


// 当天时间段
- (NSPredicate *)predicateForSamplesToday
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *now = [NSDate date];
    
    NSDate *startDate = [calendar startOfDayForDate:now];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    return [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
}

- (void)saveStepCountIntoHealthStore:(double)stepCount
{
    // Save the user's step count into HealthKit.
    HKUnit *countUnit = [HKUnit countUnit];
    HKQuantity *countUnitQuantity = [HKQuantity quantityWithUnit:countUnit doubleValue:stepCount];
    
    HKQuantityType *countUnitType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    NSDate *now = [NSDate date];
    
    HKQuantitySample *stepCountSample = [HKQuantitySample quantitySampleWithType:countUnitType quantity:countUnitQuantity startDate:now endDate:now];
    
    [self.healthStore saveObject:stepCountSample withCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"An error occured saving the step count sample %@. In your app, try to handle this gracefully. The error was: %@.", stepCountSample, error);
            abort();
        }
        
        [self updateStepCountLabel];
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self.stepsTextField resignFirstResponder];
    return YES;
}

@end
