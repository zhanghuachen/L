#include<stdio.h>
static int input[6*6] = {
    1, 2, 3, 4, 5, 6,
    1, 2, 3, 4, 5, 6,
    1, 2, 3, 4, 5, 6,
    1, 1, 1, 1, 1, 6,
    1, 0, 1, 1, 0, 1,
};
static int weight[3*3] ={
    2, 0, 0,
    4, 1, 0,
    3, 0, 0
};
int record(){
	int t;
	__asm__ __volatile__(
		"rdcycle %[rdcycle]"
		:[rdcycle] "=r"(t)
	);
	return t;
}
void convolution_2d(int *input, int *kernel, int *output) {
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            output[i*4+j] = 0;
            for (int m = 0; m < 3; m++) {
                for (int n = 0; n < 3; n++) {
                    output[i*4+j] += input[(i + m)*6+j + n] * kernel[m*3+n];

                }
            }
            //  printf("%d ",output[4*i+j]);
        }
        printf("\n");
    }
}
int main()
{
    int output1[16];
    // generate_sparse_matrices(values,index,nnz_per_matrix,weight);
    // print_sparse_matrices(values,index,nnz_per_matrix);
    // P_SPCNN(1,4,3,1);
    // IL_SPCNN(input,nnz_per_matrix);
    // SPGEMM_EX(values,index);
    // SPCNN_WB(output);
    long long  t1 =record();//174
    convolution_2d(input,weight,output1);
    long long t2 =record();//26452
    for (int i=0 ;i<4;i++)
    {
        for(int j=0;j<4;j++){
            printf("%d ",output1[4*i+j]);
        }
        printf("\n");
    }
    printf("总体耗时:%lld\n",t2-t1); //141
}
