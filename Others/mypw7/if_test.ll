; ModuleID = 'if_test.c'
source_filename = "if_test.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@a = dso_local global i32 0, align 4

; Function Attrs: noinline nounwind optnone uwtable
define dso_local i32 @main() #0 {
  %1 = alloca i32, align 4
  store i32 0, i32* %1, align 4
  store i32 10, i32* @a, align 4
  %2 = load i32, i32* @a, align 4
  %3 = icmp sgt i32 %2, 20
  br i1 %3, label %7, label %4

4:                                                ; preds = %0
  %5 = load i32, i32* @a, align 4
  %6 = icmp slt i32 %5, 6
  br i1 %6, label %7, label %9

7:                                                ; preds = %4, %0
  %8 = load i32, i32* @a, align 4
  store i32 %8, i32* %1, align 4
  br label %12

9:                                                ; preds = %4
  %10 = load i32, i32* @a, align 4
  %11 = sub nsw i32 0, %10
  store i32 %11, i32* %1, align 4
  br label %12

12:                                               ; preds = %9, %7
  %13 = load i32, i32* %1, align 4
  ret i32 %13
}

attributes #0 = { noinline nounwind optnone uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "frame-pointer"="all" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 11.0.0 (https://github.com/llvm/llvm-project.git 0160ad802e899c2922bc9b29564080c22eb0908c)"}
