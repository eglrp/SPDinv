#include "stdafx.h"

#include "cl_spd_inv.h"
#include "cl_common.h"


/*
��������Ǿ���������
ʹ��3x3�Ŀ飬ʹ��opencl 2.0��QUEUE_ON_DEVICE����
����ֵ��=0��ʾ������ȷ
������buf_spd_A�������ǣ������Խǿ飩�������ǲ��䡣
*/
dtype trigMat_inv_m1(int mat_size, SPDInv_structPtr SPDInvPtr, dtype *outMat)
{
	cl_command_queue queue_device;
	cl_int err;
	dtype ret = 0.0;
	//int blk_mat_size;

	//********���ò���**********/
	int j = 0;
	err = clSetKernelArg(SPDInvPtr->kern_trigMat_inv_m1, 0, sizeof(cl_mem), &SPDInvPtr->buf_spd_A);
	err |= clSetKernelArg(SPDInvPtr->kern_trigMat_inv_m1, 1, sizeof(cl_mem), &SPDInvPtr->buf_aux);
	err |= clSetKernelArg(SPDInvPtr->kern_trigMat_inv_m1, 2, sizeof(cl_mem), &SPDInvPtr->buf_ret);
	err |= clSetKernelArg(SPDInvPtr->kern_trigMat_inv_m1, 3, sizeof(int), &mat_size);
	err |= clSetKernelArg(SPDInvPtr->kern_trigMat_inv_m1, 4, sizeof(int), &j);

	//ִ���ں�,
	size_t global_size[2] = { mat_size,3 };
	size_t local_size[2] = { 3,3 };
	err = clEnqueueNDRangeKernel(SPDInvPtr->queue, SPDInvPtr->kern_trigMat_inv_m1,
		2, NULL,	//2D work space
		global_size,
		local_size,	//local_size,
		0, NULL, NULL);
	checkErr(err, __FILE__, __LINE__);
	clFinish(SPDInvPtr->queue);

	err = clEnqueueReadBuffer(SPDInvPtr->queue, SPDInvPtr->buf_ret, CL_TRUE, 0,
		sizeof(ret), &ret, 0, NULL, NULL);
	checkErr(err, __FILE__, __LINE__);
	
#if DEBUG_TRIGMAT_INV==1
	err = clEnqueueReadBuffer(SPDInvPtr->queue, SPDInvPtr->buf_spd_A, CL_TRUE, 0,
		sizeof(dtype)*mat_size*mat_size, outMat, 0, NULL, NULL);
	checkErr(err, __FILE__, __LINE__);

	//display for check
	printf("L_inv:\n");
	for (int r = 0; r < mat_size; r++)
	{
		for (int c = 0; c < mat_size; c++)
			printf("%le\t", outMat[r*mat_size + c]);
		printf("\n");
	}
#endif
	return ret;
}