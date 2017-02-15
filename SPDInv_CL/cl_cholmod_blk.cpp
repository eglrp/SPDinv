#include "stdafx.h"

#include <math.h>

#include "cl_spd_inv.h"
#include "cl_common.h"


/*
����cholesky�ֽ⣨modified cholesky����
�����˶Է�����������,enqueue on device
���룺
matBuf:���ֽⷽ��,�ߴ�ΪmatSize*matSize
auxBuf: >=2*matSize
diagBuf: ���ԭʼ����ĶԽ�Ԫ��
�����
matBuf���������Ǿ���Ϊ�ֽ�Ľ����
outMat����copyOutΪTrueʱ�����������outMat
*/
//dtype cholesky_mod(int matsize, SPDInv_structPtr SPDInvPtr, dtype *outMat, bool copyOut)
void cholmod_blk(cl_command_queue queue, cl_kernel kern_cholmod_blk, cl_kernel kern_mat_max,
	cl_mem matBuf, cl_mem auxBuf, cl_mem diagInvBuf, cl_mem diagBuf, cl_mem retBuf,
	int matSize, dtype *outMat, bool copyOut)
{
	int argNum;
	cl_int err;
	dtype beta, delta, ret;
	dtype *debug;
	dtype data[2 * 18];

	//get delta,beta
	get_delta_beta(queue, kern_mat_max, matBuf, auxBuf, matSize, &delta, &beta);

	//set kernel arguments
	argNum = 0;
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(cl_mem), &matBuf);
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(cl_mem), &auxBuf);
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(cl_mem), &diagInvBuf);
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(cl_mem), &diagBuf);
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(cl_mem), &retBuf);
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(dtype) * 9, NULL);		//T_ii��
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(dtype) * 6, NULL);		//L_ii,ֻ�洢������
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(int), &matSize);
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(dtype), &beta);
	err = clSetKernelArg(kern_cholmod_blk, argNum++, sizeof(dtype), &delta);
	checkErr(err, __FILE__, __LINE__);

	//for (int j = 0; j < matSize/3; j++) {
	int j = 0;
		err = clSetKernelArg(kern_cholmod_blk, argNum, sizeof(int), &j);		//�����ĵ�j��
																				//ִ���ں�
		size_t global_size[2] = { 3,3 };
		size_t local_size[2] = { 3,3 };
		err = clEnqueueNDRangeKernel(queue, kern_cholmod_blk,
			2, NULL,	//1D work space
			global_size,
			local_size,
			0, NULL, NULL);
		checkErr(err, __FILE__, __LINE__);
		clFinish(queue);

		printBuf2D(stdout, queue, matBuf, matSize, matSize, "******A:");
		printBuf2D(stdout, queue, diagInvBuf, 3, matSize, "******Linv:");
		printBuf2D(stdout, queue, auxBuf, 3, matSize, "******aux:");
		printBuf1D(stdout, queue, diagBuf, matSize, "******diag:");
		printBuf1D(stdout, queue, retBuf, 1, "******ret:");
	//}

	err = clEnqueueReadBuffer(queue, retBuf, CL_TRUE, 0,
		sizeof(dtype), &ret, 0, NULL, NULL);

	// ��ȡ���
	if (copyOut)
	{
		err = clEnqueueReadBuffer(queue, matBuf, CL_TRUE, 0,
			sizeof(dtype)*matSize*matSize, outMat, 0, NULL, NULL);
		checkErr(err, __FILE__, __LINE__);
	}

#if DEBUG_CHOLESKY==1
	if (copyOut)		//
		debug = outMat;
	else {
		debug = (dtype*)malloc(sizeof(dtype)*matSize*matSize);
		err = clEnqueueReadBuffer(queue, matBuf, CL_TRUE, 0,
			sizeof(dtype)*matSize*matSize, debug, 0, NULL, NULL);
		checkErr(err, __FILE__, __LINE__);
	}

	printf("L(cholesky):\n");
	for (int r = 0; r < matSize; r++)
	{
		for (int c = 0; c < matSize; c++)
			printf("%le\t", debug[r*matSize + c]);
		printf("\n");
	}
	if (!copyOut)		//
		free(debug);

#endif
}