#define dtype double

/*
���������ǿ�������, �浽in��������
��kernelֻ�����i��б�߿飬Ȼ����ü�����һ��б�߿�i+1��kernel_trigMatInv
*/
__kernel void kern_trigMat_inv_m1(
	__global dtype *in,
	__global dtype *diagBlk,	//����cholesky�����Lii^-1
	__global dtype *ret,
	const int mat_size,		//ԭʼ����ĳߴ�
	const int ii			//��ii��б�߿�
)
{
	int addr, addr2, ijuv_addr, jivu_addr;

	int tr = get_global_id(0);
	int j = (int)(tr / 3);		//��ǰ�������к�
	int i = ii + j;
	int u = tr - j * 3;			//��ǰ�����ĵ�u��
	int v = get_global_id(1);	//��ǰ�����ĵ�v��

	dtype tt;
	dtype L0, L1, L2, L3, L4, L5;

	ijuv_addr = (i * 3 + u)*mat_size + j * 3 + v;
	jivu_addr = (j * 3 + v)*mat_size + i * 3 + u;

	//����ǶԽ��߿飬��diagBlkȡ����Lii^-1���浽out�ĶԽ�����
	if (i == j)
	{
		in[ijuv_addr] = diagBlk[i*9+ v* 3 + u];
		barrier(CLK_GLOBAL_MEM_FENCE);	//ͬ������ʹ��mat��ȡ���
	}
	else
	{
		//���ڷǶԽǿ�
		//1������T_ij=sum(L_ik*X_kj), k=j to i-1,  ע��X_kj^t����out��������
		tt = 0.0;
		for (int k = j; k < i; k++)
		{
			//L_ik��u���� X_kj^t��v�еĵ��
			addr = (i * 3 + u)*mat_size + k * 3;
			addr2 = (j * 3 + v)*mat_size + k * 3;
			tt += in[addr++] * in[addr2++];
			tt += in[addr++] * in[addr2++];
			tt += in[addr] * in[addr2];
		}
		in[jivu_addr] = tt;		//T_ij^t��u,vԪ�ش浽in��������

		//ͬ��
		barrier(CLK_GLOBAL_MEM_FENCE);

		//����X_ij=(L_ii^-1)*T_ij, ���洢����L_ii^-t ��T_ij^t, ��ôӦ��ȡL_ii^-t��u����T_ij^t��v�еĵ��
		tt = 0.0;
		addr = i * 3 * mat_size + i * 3 + u;		//u�е�һ��Ԫ��
		addr2 = (j * 3 + v)*mat_size + i * 3;	//v�е�һ��Ԫ��
		tt += in[addr] * in[addr2++];
		tt += in[addr + mat_size] * in[addr2++];
		tt += in[addr + 2 * mat_size] * in[addr2];

		//ͬ��
		barrier(CLK_GLOBAL_MEM_FENCE);
		if (i != j) {
			in[jivu_addr] = -tt;
			//in[ijuv_addr] = 0;
		}
	}

	//����ii+1��б�߿�ļ����kernel
	addr = mat_size - (ii + 1) * 3;		//ʣ����������
	if (tr == 0 && v == 0 && addr>0)
	{
		void(^kernel_trigMatInv_wrapper)(void) =
			^{
			kern_trigMat_inv_m1(in,diagBlk, ret, mat_size, ii + 1);
		};
		size_t    global_size[2] = { addr, 3 };
		size_t    local_size[2] = { 3,3 };
		ndrange_t ndrange = ndrange_2D(global_size, local_size);
		enqueue_kernel(
			get_default_queue(),
			CLK_ENQUEUE_FLAGS_WAIT_KERNEL,
			ndrange, kernel_trigMatInv_wrapper
		);
	}
}
