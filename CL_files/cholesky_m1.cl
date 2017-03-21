
/*
require: OpenCL>2.0
*/

#define dtype double
#define dtype3 double3


__kernel void kern_cholesky_m1_s2(
	__global dtype* mat,
	__global dtype* diagInv,
	__global dtype* ret,
	const int mat_size,
	const int j);

/*
cholesky分解
step 1: 计算Tij=Aij-sum(Lik*Ljk^t)中的uv元素，以及处理对角块
j为块矩阵的当前列
*/
__kernel void kern_cholesky_m1(
	__global dtype *mat,		//原始矩阵 和 结果矩阵
	__global dtype *diagInv,	//输出的Lii^-1, 可供三角矩阵求逆使用
	__global dtype *ret,
	__local dtype *T,
	__local dtype *L,
	const int mat_size,
	const int j)
{
	dtype3 *ptr1, *ptr2;
	dtype sum, t1, t2, t3,t4,t5;
	int u = get_local_id(0);
	int v = get_local_id(1);
	int i = j + get_group_id(0);

	if (get_global_id(0) == 0 && get_global_id(1) == 0 )
	{
		*ret = 0.0;
	}

	//计算Tij = Aij - sum(Lik*Ljk^t)中的uv元素
	int ijuv_addr = (i * 3 + u)*mat_size + j * 3 + v;
	sum = mat[ijuv_addr];	//Aij_uv元素
	for (int k = 0; k < j; k++)
	{
		int Lik_base = (i * 3 + u)*mat_size + k * 3;		//Lik的第u行
		int Ljk_base = (j * 3 + v)*mat_size + k * 3;		//Ljk的第v行
		//sum -= mat[Lik_base++] * mat[Ljk_base++];
		//sum -= mat[Lik_base++] * mat[Ljk_base++];
		//sum -= mat[Lik_base] * mat[Ljk_base];
		ptr1 = (dtype3 *)&mat[Lik_base];
		ptr2 = (dtype3 *)&mat[Ljk_base];
		sum -= dot(*ptr1, *ptr2);
	}
	mat[ijuv_addr] = sum;		//保存Tij_uv到原矩阵
	T[u * 3 + v] = sum;		//同时保存到本地缓存，对角线块使用

	barrier(CLK_GLOBAL_MEM_FENCE);		//工作组同步

	//处理对角块,计算Lii
	if (i == j) {
		switch (u * 3 + v)
		{
		case 0:		//L00 or L(0)
			L[0] = sqrt(T[0]);
			mat[ijuv_addr] = L[0];
			if (!isfinite(L[0])) *ret = 1.0;
			break;
		case 1:		//L01,L02
		case 2:
			mat[ijuv_addr] = 0;
			break;
		case 3:		//L10
			L[1] = T[1 * 3 + 0] / sqrt(T[0]);
			mat[ijuv_addr] = L[1];
			if (!isfinite(L[1])) *ret = 1.0;
			break;
		case 4:		//L11
			L[2] = sqrt(T[1 * 3 + 1] - T[1 * 3 + 0] * T[1 * 3 + 0] / T[0]);;
			mat[ijuv_addr] = L[2];
			if (!isfinite(L[2])) *ret = 1.0;
			break;
		case 5:		//L12
			mat[ijuv_addr] = 0;
			break;
		case 6:		//L20 or L(3)
			L[3] = T[2 * 3 + 0] / sqrt(T[0]);
			mat[ijuv_addr] = L[3];
			if (!isfinite(L[3])) *ret = 1.0;
			break;
		case 7:		//L21 or L(4)
			L[4] = sqrt(T[0] / (T[0] * T[1 * 3 + 1] - T[1 * 3 + 0] * T[1 * 3 + 0]))*(T[2 * 3 + 1] - T[1 * 3 + 0] * T[2 * 3 + 0] / T[0]);
			mat[ijuv_addr] = L[4];
			if (!isfinite(L[4])) *ret = 1.0;
			break;
		case 8:		//L22 or (5)
			//t1 = T[0] / (T[0] * T[1 * 3 + 1] - T[1 * 3 + 0] * T[1 * 3 + 0]);
			//t2 = T[2 * 3 + 1] - T[1 * 3 + 0] * T[2 * 3 + 0] / T[0];
			//t2 = t2*t2;
			//L[5] = sqrt(T[2 * 3 + 2] - T[2 * 3 + 0] * T[2 * 3 + 0] / T[0] - t1*t2);
			t1 = -T[2 * 3 + 2] * T[1 * 3 + 0] * T[1 * 3 + 0];
			t2 = 2 * T[2 * 3 + 1] * T[1 * 3 + 0] * T[2 * 3 + 0];
			t3 = -T[1 * 3 + 1] * T[2 * 3 + 0] * T[2 * 3 + 0];
			t4 = T[0 * 3 + 0] * (T[1 * 3 + 1] * T[2 * 3 + 2] - T[2 * 3 + 1] * T[2 * 3 + 1]);
			t5 = -T[1 * 3 + 0] * T[1 * 3 + 0] + T[0 * 3 + 0] * T[1 * 3 + 1];
			L[5] =sqrt( (t1 + t2 + t3 + t4) / t5);
			mat[ijuv_addr] = L[5];
			if (!isfinite(L[5])) *ret = 1.0;
			break;
		default:
			break;
		}
	}
	//计算Lii的逆矩阵
	barrier(CLK_GLOBAL_MEM_FENCE);		//工作组同步
	if (i == j) {
		int diag_addr = j * 3 * 3 + u * 3 + v;
		switch (u * 3 + v)
		{
		case 0:		//L00 or L(0)
			t1 = 1 / L[0];
			diagInv[diag_addr] = t1;
			if (!isfinite(t1)) *ret = 1.0;
			break;
		case 1:		//L01,L02
		case 2:
			diagInv[diag_addr] = 0;
			break;
		case 3:		//L10 or L(1)
			t1 = -L[1] / (L[0] * L[2]);
			diagInv[diag_addr] = t1;
			if (!isfinite(t1)) *ret = 1.0;
			break;
		case 4:		//L11 or L(2)
			t1 = 1 / L[2];
			diagInv[diag_addr] = t1;
			if (!isfinite(t1)) *ret = 1.0;
			break;
		case 5:		//L12
			diagInv[diag_addr] = 0;
			break;
		case 6:		//L20 or L(3)
			t1 = (L[1] * L[4] - L[2] * L[3]) / (L[0] * L[2] * L[5]);
			diagInv[diag_addr] = t1;
			if (!isfinite(t1)) *ret = 1.0;
			break;
		case 7:		//L21 or L(4)
			t1 = -L[4] / (L[2] * L[5]);
			diagInv[diag_addr] = t1;
			if (!isfinite(t1)) *ret = 1.0;
			break;
		case 8:		//L22 or L(5)
			t1 = 1 / L[5];
			diagInv[diag_addr] = t1;
			if (!isfinite(t1)) *ret = 1.0;
			break;
		default:
			break;
		}
	}
	barrier(CLK_GLOBAL_MEM_FENCE);		//工作组同步

	/************************************************************************/
	/************************************************************************/
	//调用kern_cholesky_m5_s2
	if (get_global_id(0) == 0 && get_global_id(1) == 0 && get_global_size(0) >3 && *ret == 0.0)
	{
		//urow_base = mat_size - (j + 1) * 3;		//剩余块的总行数
		void(^s2_wrapper)(void) = ^{
			kern_cholesky_m1_s2(mat, diagInv, ret, mat_size, j);
		};
		size_t    global_size[2] = { get_global_size(0) - 3, 3 };
		size_t    local_size[2] = { 3,3 };
		ndrange_t ndrange = ndrange_2D(global_size, local_size);
		enqueue_kernel(
			get_default_queue(),
			CLK_ENQUEUE_FLAGS_WAIT_KERNEL,
			ndrange, s2_wrapper
		);
	}

}


/*
cholesky分解
step 2 计算剩余元素, Lij=Tij*(Ljj^-t)
*/
__kernel void kern_cholesky_m1_s2(
	__global dtype* mat,
	__global dtype* diagInv,
	__global dtype* ret,
	const int mat_size,
	const int j)
{
	dtype3 *ptr1, *ptr2;
	dtype sum = 0.0;
	int u = get_local_id(0);
	int v = get_local_id(1);
	int i = j + get_group_id(0) + 1;

	//计算Lij=Tij*(Ljj^-t)中的uv元素
	int ijuv_addr = (i * 3 + u)*mat_size + j * 3 + v;
	int jivu_addr = (j * 3 + v)*mat_size + i * 3 + u;
	int urow_base = (i * 3 + u)*mat_size + j * 3;	//Tij的第u行
	int vrow_base = j * 3 * 3 + v * 3;				//(Ljj^-1)的第v行

	ptr1 = (dtype3 *)&mat[urow_base];
	ptr2 = (dtype3 *)&diagInv[vrow_base];
	sum += dot(*ptr1, *ptr2);
	//sum += mat[urow_base++] * diagInv[vrow_base++];
	//sum += mat[urow_base++] * diagInv[vrow_base++];
	//sum += mat[urow_base] * diagInv[vrow_base];

	barrier(CLK_LOCAL_MEM_FENCE);		//工作组同步

	mat[ijuv_addr] = sum;
	mat[jivu_addr] = 0;

	/***********************************************************/
	//调用kern_cholesky_m3_s1
	if (get_global_id(0) == 0 && get_global_id(1) == 0 && get_global_size(0) >= 3 && *ret == 0.0)
	{
		void(^s1_wrapper)(local void *, local void *) =
			^ (local void *TT, local void *LL) {
			kern_cholesky_m1(mat, diagInv, ret, TT, LL, mat_size, j + 1);
		};
		size_t    global_size[2] = { get_global_size(0), 3 };
		size_t    local_size[2] = { 3,3 };
		ndrange_t ndrange = ndrange_2D(global_size, local_size);
		enqueue_kernel(
			get_default_queue(),
			CLK_ENQUEUE_FLAGS_WAIT_KERNEL,
			ndrange, s1_wrapper,
			(unsigned int)(3 * 3 * sizeof(dtype)),		//size of local memory TT
			(unsigned int)(6 * sizeof(dtype))			//size of local memory LL
		);
	}

}


