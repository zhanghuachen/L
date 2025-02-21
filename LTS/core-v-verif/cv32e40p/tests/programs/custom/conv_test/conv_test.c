#include <stdio.h>
// conv_size: 2^5
typedef int u8;



//MODE
void mode_control(u8 *mode) {
    int res1 = 0, res2 = 0;
    asm volatile (
         "addi zero,zero,0\n"
        ".insn r 0x77, 2, 0, %[null1], %[mode_con], %[null2]"
        :[null1] "=r"(res1)
        :[mode_con] "r" (mode), [null2] "r" (res2) 
    );
}

void weight_load(u8 *kernel_addr, u8 kernel_size) {
    int res = 0;
    asm volatile ( 
        "addi zero,zero,0\n"
        ".insn r 0x77, 1, 0, %[null], %[ker_addr], %[ker_size]"
        :[null] "=r"(res)
        :[ker_addr] "r" (kernel_addr), [ker_size] "r" (kernel_size) 
     );
}


// load active
void active_load(u8 *conv_addr, u8 conv_size) {
    int res = 0;
    asm volatile ( 
        "addi zero,zero,0\n"
        ".insn r 0x77, 2, 1, %[null], %[cv_addr], %[cv_size]"
        :[null] "=r"(res)
        :[cv_addr] "r" (conv_addr), [cv_size] "r" (conv_size) 
);
}

// Write-back function to store results
void wb(u8 *res_addr) {
    int res1 = 0, res2 = 0;
    asm volatile ( 
        "addi zero,zero,0\n"
        ".insn r 0x77, 1, 1, %[null1], %[rs_addr], %[null2]"
        :[null1] "=r"(res1)
        :[rs_addr] "r" (res_addr), [null2] "r" (res2) 
     );
}

// // Finish function to indicate the end of processing
// void finish() {
//     int res1 = 0, res2 = 0, res3 = 0;
//     asm volatile ( 
//         "addi zero,zero,0\n"
//         ".insn r 0x77, 2, 1, %[null1], %[null2], %[null3]"
//         :[null1] "=r"(res1)
//         :[null2] "r" (res2), [null3] "r" (res3) 
//      );
//      printf("Hello world in finish\n");
//      return;
// }

// Function to read the cycle count
static inline unsigned long rdcycle() {
    unsigned int cycle;
    __asm__ volatile ("rdcycle %0" : "=r" (cycle));
    return cycle;
}





static unsigned int weightnum[2] = {0x00010002,0x00010003};
static unsigned int activenum[2] = {0x00000001,0x00010001};     

   
    

int main() {

    unsigned long start_time, end_time;
    unsigned long total = 0;

 
    int res1[4]; 
    int res2;
    
    

    mode_control(128);
    weight_load(weightnum,2);
    start_time = rdcycle(); // Start cycle count
    active_load(activenum,2);
    end_time = rdcycle(); // End cycle count
    wb(res1);

    mode_control(0);
    weight_load(weightnum,2);
    active_load(activenum,2);
    wb(&res2);



    
    printf("Total cycles taken: %lu\n", end_time - start_time);

    // printf("res1: %d %d %d %d\n", res1[0],res1[1],res1[2],res1[3]);
    // printf("res1: %d\n", res1[0]);
    printf("res2: %d\n", res2);

    int a[4] = {0x0003, 0x0001, 0x0002, 0x0001};
    int w[4] = {0x0001, 0x0001, 0x0001, 0x0000};
    int ress = 0;

    unsigned long sum_time = 0;

    start_time = rdcycle(); // Start cycle count
    ress += a[0] * w[0];
    end_time = rdcycle(); // End cycle count
    sum_time += end_time - start_time;
    start_time = rdcycle(); // Start cycle count
    ress += a[1] * w[1];
    end_time = rdcycle(); // End cycle count
    sum_time += end_time - start_time;
    start_time = rdcycle(); // Start cycle count
    ress += a[2] * w[2];
    end_time = rdcycle(); // End cycle count
    sum_time += end_time - start_time;
    start_time = rdcycle(); // Start cycle count
    ress += a[3] * w[3];
    end_time = rdcycle(); // End cycle count
    sum_time += end_time - start_time;
    printf("ress: %d\n", ress);
    printf("Nomal Total cycles taken: %lu\n", sum_time);

    // start_time = rdcycle();
    // // conv_cal_normal(input16x16, kernel3x3, res2, 216, 3);
    // end_time = rdcycle();
    // printf("Normal conv cycles: %lu\n", end_time - start_time);


    return 0;
}

