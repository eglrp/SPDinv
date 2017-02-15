#pragma once

#include <CL/cl.h>

#include "spd_inv.h"

#define KERN_FILE "../CL_files/spd_inv.cl"

#define DEV_TYPE	CL_DEVICE_TYPE_CPU

#define DEBUG_GEN_MAT		0
#define DEBUG_CHOLESKY		1
#define DEBUG_TRIGMAT_INV	0
#define DEBUG_TRIGMAT_MUL	0


typedef struct {
	cl_device_id device;
	cl_context context;
	cl_command_queue queue;
	cl_command_queue queue_dev;		//queue on device
	cl_program program;
	cl_program program_cpu;

	//buffer associated to LM
	cl_mem buf_spd_A;		//���ԭʼ���� �������������
	//cl_mem buf_spd_B;		//
	cl_mem buf_aux;			//����buffer, �ߴ�>blksize*matsize
	cl_mem buf_backup;
	cl_mem buf_diag;
	cl_mem buf_ret;

	cl_kernel kern_mat_max;
	cl_kernel kern_cholesky_m1;
	cl_kernel kern_cholesky_mod;		//��������cholesky
	cl_kernel kern_cholmod_E;
	cl_kernel kern_trigMat_inv_m1;
	cl_kernel kern_trigMat_mul;
	cl_kernel kern_cholmod_blk;			//��������cholesky, �ֿ���ʽ


}SPDInv_struct, *SPDInv_structPtr;

//maxsizeΪ��������ߴ�, maxblksizeΪ�ӿ�����ߴ�
void cl_SPDInv_setup(SPDInv_structPtr SPDInvPtr, int maxsize,int maxblksize);
void cl_SPDInv_release(SPDInv_structPtr SPDInvPtr);

dtype cholesky_m1(cl_command_queue queue, cl_kernel kern_cholesky,
	cl_mem matBuf, cl_mem diagAuxBuf, cl_mem retBuf,
	int matSize, dtype *outMat, bool copyOut);

void get_delta_beta(cl_command_queue queue, cl_kernel kern_delta_beta, cl_mem matBuf, cl_mem diagAuxBuf,
	int matsize, dtype *delta, dtype *beta);
void cholesky_mod(cl_command_queue queue, cl_kernel kern_cholesky_mod, cl_kernel kern_delta_beta,
	cl_mem matBuf, cl_mem auxBuf,cl_mem diagBuf,cl_mem retBuf,
	int matSize, dtype *outMat, bool copyOut);

void compute_cholmod_E(cl_command_queue queue, cl_kernel kern_cholmod_E,
	cl_mem matBuf, cl_mem E_Buf, int matSize, dtype *Eout);

dtype trigMat_inv_m1(int mat_size, SPDInv_structPtr SPDInvPtr,dtype *outMat);
void trigMat_mul(int mat_size, SPDInv_structPtr SPDInvPtr, dtype *outMat);

void cholmod_blk(cl_command_queue queue, cl_kernel kern_cholmod_blk, cl_kernel kern_mat_max,
	cl_mem matBuf, cl_mem auxBuf, cl_mem diagInvBuf, cl_mem diagBuf, cl_mem retBuf,
	int matSize, dtype *outMat, bool copyOut);