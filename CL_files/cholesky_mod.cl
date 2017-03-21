
/*
require: OpenCL>2.0, row_max.cl
*/

#define dtype double
#define dtype3 double3

#define MU		1e-8


/*
cholesky�ֽ⣺ �ȷֽ�L*D*L^t���ٵõ�M*M^t
step 1: ����Tij=Aij-sum(Lik*Ljk^t)�е�uvԪ�أ��Լ�����Խǿ�
jΪ�����ĵ�ǰ��
*/
__kernel void kern_cholesky_mod(
	__global dtype *mat,
	__global dtype *aux,	//�ߴ�>=2*matsize, ��һ��matsize��Ԫ�ش��d_j,�ڶ���matsize��Ԫ�ش�ŵ�ǰ�е�C_ij��
	__global dtype *diag,	//ԭ����ĶԽ�Ԫ�ء�
	__global dtype *ret,
	const int matsize,
	const dtype delta,
	const dtype beta,
	const int j)
{
	int jj_addr, ij_addr, k, t;
	dtype d_j, m_jk, C_ij, theta,tmp;
	int i = get_global_id(0)+j;

	jj_addr = j*matsize + j;
	ij_addr = i*matsize + j;

	//step 1 ����d_j
	if (i == j)
	{
		*ret = 0.0;
		d_j = mat[jj_addr];
		diag[i] = d_j;
		for (k = 0; k < j; k++)
		{
			m_jk = mat[j*matsize + k];
			d_j -=m_jk*m_jk;
		}
		d_j = fabs(d_j);
		d_j = fmax(d_j, delta);
		mat[jj_addr] = sqrt(d_j);
		aux[j] = d_j;
	}
	barrier(CLK_GLOBAL_MEM_FENCE);		//������ͬ��

	//step 2 ����C_ij��M_ij,�浽������, ������ʱL_ij���浽aux�ĵ�2��matsize�ռ�
	if (i != j)
	{
		C_ij = mat[ij_addr];
		for (k = 0; k < j; k++)
		{
			C_ij -= mat[i*matsize + k] * mat[j*matsize + k];
		}
		aux[matsize + i] = C_ij;
		mat[ij_addr] = C_ij / mat[jj_addr];	//M_ij=C_ij/sqrt(d_j)
		if (mat[ij_addr] > beta)		//check |m_ij|>beta
			*ret = 1.0;
		mat[j*matsize + i] = 0;
	}
	barrier(CLK_GLOBAL_MEM_FENCE);		//������ͬ��
	
	//step 3 check m_ij and modify d_j
	//if check failed, find max mu_ij and modify d_j
	if (i == j && (*ret)==1.0)
	{
		theta = 0.0;
		t = 2 * matsize;
		for (k = matsize+j + 1; k < t; k++) {
			tmp =fabs(aux[k]);
			//tmp = mat[k*matsize + j];
			theta = fmax(theta, tmp);
		}
		//max_val = max_val / (mat[jj_addr] * mat[jj_addr]);
		mat[jj_addr] = theta /beta;		//modified d_j
		aux[j] = mat[jj_addr] * mat[jj_addr];
	}
	barrier(CLK_GLOBAL_MEM_FENCE);		//������ͬ��

	//step 4 ���¼���m_ij
	if (i!=j && (*ret)==1.0)
	{
		mat[i*matsize + j] = aux[matsize + i] / mat[jj_addr];
	}
	barrier(CLK_GLOBAL_MEM_FENCE);		//������ͬ��

	/************************************************************************/
	/************************************************************************/
	///*
	//����kern_cholesky_mod
	if (get_global_id(0) == 0 && (j+1)<matsize)
	{
		void(^kern_wrapper)(void) =
			^{
			kern_cholesky_mod(mat, aux,diag, ret, matsize,delta,beta,j+1);
		};
		size_t    global_size =get_global_size(0) -1;
		size_t    local_size = global_size;
		ndrange_t ndrange = ndrange_1D(global_size, local_size);
		enqueue_kernel(
			get_default_queue(),
			CLK_ENQUEUE_FLAGS_WAIT_KERNEL,
			ndrange, kern_wrapper
			);
	}
	//*/
}

/***********************************************************************************************/
/***********************************************************************************************/

/*
ȡÿһ�е����ֵ���浽out
���excludeDiag��Ϊ0�����ų��Խ�Ԫ�أ������Խ�Ԫ�ش浽out�ĵڶ��У���ʱout�����еĿռ䣩��
*/
__kernel void kern_mat_max(
	__global dtype *mat,
	__global dtype *out,
	const int outOffset,
	const int mat_size,
	const int excludeDiag)
{
	dtype max, t1;
	int r, inAddr, outAddr;

	r = get_global_id(0);
	inAddr = r*mat_size;
	max = 0;
	for (int k = 0; k < mat_size; k++)
	{
		if (excludeDiag && r == k) {
			inAddr++;

			continue;
		}
		t1 = fabs(mat[inAddr++]);
		if (t1 > max)
			max = t1;
	}
	outAddr = r + outOffset;
	out[outAddr] = max;
	//���excludeDiagΪ�棬�����еĶԽ�Ԫ�ؽ��д洢
	if (excludeDiag)
		out[outAddr + mat_size] = mat[r*mat_size + r];
}




__kernel void kern_cholmod_E(
	__global dtype *mat,
	__global dtype *diag,		//ԭ����ĶԽ�Ԫ��, �Լ������E
	const int mat_size)
{ 
	int addr;
	dtype sum;
	int i = get_global_id(0);

	sum = 0.0;
	addr = i*mat_size;
	for (int k = 0;k <= i;k++)
	{
		sum += mat[addr] * mat[addr];
		addr++;
	}
	diag[i] = sum-diag[i];
}	   