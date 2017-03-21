#include "stdafx.h"

#include <math.h>

#include "cl_spd_inv.h"
#include "cl_common.h"

/*
cholesky�ֽ⣺����1
���ԣ�
�ֿ鲢�з�����enqueue on device
���룺
matBuf--���ֽⷽ��, matSize*matSize
diagAuxBuf--����Buffer, >=3*matSize
�����
matBuf--�������Ǵ�ŷֽ���
diagAuxBuf--���Ljj^-1�ӿ�
outMat!=NULL �򽫷ֽ���������outMat
ret= --> 0.0 good 1.0 not good
*/
dtype cholesky_m1(cl_command_queue queue, cl_kernel kern_cholesky,
	cl_mem matBuf, cl_mem diagAuxBuf, cl_mem retBuf,
	int matSize, dtype *outMat)
{
	cl_int err;
	dtype ret;

	//set kernel arguments
	err = clSetKernelArg(kern_cholesky, 0, sizeof(cl_mem), &matBuf);
	err = clSetKernelArg(kern_cholesky, 1, sizeof(cl_mem), &diagAuxBuf);
	err = clSetKernelArg(kern_cholesky, 2, sizeof(cl_mem), &retBuf);
	err = clSetKernelArg(kern_cholesky, 3, sizeof(dtype) * 9, NULL);		//T_ii��
	err = clSetKernelArg(kern_cholesky, 4, sizeof(dtype) * 6, NULL);		//L_ii,ֻ�洢������
	err = clSetKernelArg(kern_cholesky, 5, sizeof(int), &matSize);

	//ִ���ں�
	int j = 0;
	size_t global_size[2] = { matSize,3 };
	size_t local_size[2] = { 3,3 };
	err = clSetKernelArg(kern_cholesky, 6, sizeof(int), &j);		//�����ĵ�j��
	err = clEnqueueNDRangeKernel(queue, kern_cholesky,
		2, NULL,	//2D work space
		global_size,
		local_size,
		0, NULL, NULL);
	checkErr(err, __FILE__, __LINE__);
	clFinish(queue);

	err = clEnqueueReadBuffer(queue, retBuf, CL_TRUE, 0,
		sizeof(ret), &ret, 0, NULL, NULL);
	checkErr(err, __FILE__, __LINE__);

	// ��ȡ���
	if (outMat!=NULL)
	{
		err = clEnqueueReadBuffer(queue, matBuf, CL_TRUE, 0,
			sizeof(dtype)*matSize*matSize, outMat, 0, NULL, NULL);
		checkErr(err, __FILE__, __LINE__);
	}

#if DEBUG_CHOLESKY==1
	printBuf2D(stdout, queue, matBuf, matSize, matSize, "L(cholesky):");
	printBuf2D(stdout, queue, diagAuxBuf, 3, matSize, "diagInv:");

#endif
	return ret;
}

