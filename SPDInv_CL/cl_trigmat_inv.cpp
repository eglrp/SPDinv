#include "stdafx.h"

#include "cl_spd_inv.h"
#include "cl_common.h"


/*
��������Ǿ���������
���ԣ�
	ʹ��3x3�Ŀ飬
	ʹ��opencl 2.0��QUEUE_ON_DEVICE����
���룺
	matBufΪ�����Ǿ���
	auxBufΪ3x3�Խǿ�������
�����
	����ֵ��=0��ʾ������ȷ
	������buf_spd_A�������ǣ������Խǿ飩�������ǲ�������
*/
dtype trigMat_inv_m1(cl_command_queue queue, cl_kernel kern_trigMat_inv, cl_mem matBuf, cl_mem auxBuf, 
	cl_mem retBuf, int mat_size, dtype *outMat)
{
	cl_command_queue queue_device;
	cl_int err;
	dtype ret = 0.0;
	//int blk_mat_size;

	//********���ò���**********/
	int j = 0;
	err = clSetKernelArg(kern_trigMat_inv, 0, sizeof(cl_mem), &matBuf);
	err |= clSetKernelArg(kern_trigMat_inv, 1, sizeof(cl_mem), &auxBuf);
	err |= clSetKernelArg(kern_trigMat_inv, 2, sizeof(cl_mem), &retBuf);
	err |= clSetKernelArg(kern_trigMat_inv, 3, sizeof(int), &mat_size);
	err |= clSetKernelArg(kern_trigMat_inv, 4, sizeof(int), &j);

	//ִ���ں�,
	size_t global_size[2] = { mat_size,3 };
	size_t local_size[2] = { 3,3 };
	err = clEnqueueNDRangeKernel(queue, kern_trigMat_inv,
		2, NULL,	//2D work space
		global_size,
		local_size,	//local_size,
		0, NULL, NULL);
	checkErr(err, __FILE__, __LINE__);
	clFinish(queue);

	err = clEnqueueReadBuffer(queue, retBuf, CL_TRUE, 0,
		sizeof(ret), &ret, 0, NULL, NULL);
	checkErr(err, __FILE__, __LINE__);

	if (outMat != NULL)
	{
		err = clEnqueueReadBuffer(queue, matBuf, CL_TRUE, 0,
			sizeof(dtype)*mat_size*mat_size, outMat, 0, NULL, NULL);
		checkErr(err, __FILE__, __LINE__);
	}
	
#if DEBUG_TRIGMAT_INV==1
	printBuf2D(stdout, queue, matBuf, mat_size, mat_size, "Linv:");
#endif
	return ret;
}