export type MediaFormStatus = "idle" | "error" | "success";

export type ProductMediaVariantOption = {
  id: string;
  sku: string;
  name: string | null;
  label: string;
};

export type ProductMediaImage = {
  id: string;
  productId: string;
  variantId: string | null;
  variantLabel: string | null;
  storagePath: string;
  previewUrl: string | null;
  altText: string | null;
  sortOrder: number;
  isPrimary: boolean;
  scopeLabel: string;
  primaryLabel: string;
  updatedAt: string;
};

export type ProductMediaPageData = {
  productId: string;
  productName: string;
  images: ProductMediaImage[];
  variants: ProductMediaVariantOption[];
};

export type UploadMediaFormValues = {
  altText: string;
  variantId: string;
  setPrimary: boolean;
};

export type UploadMediaFormState = {
  status: MediaFormStatus;
  message: string;
  fieldErrors: {
    image?: string;
    altText?: string;
    variantId?: string;
  };
  values: UploadMediaFormValues;
};

export type UpdateMediaFormValues = {
  altText: string;
  variantId: string;
  sortOrder: string;
};

export type UpdateMediaFormState = {
  status: MediaFormStatus;
  message: string;
  fieldErrors: {
    altText?: string;
    variantId?: string;
    sortOrder?: string;
  };
  values: UpdateMediaFormValues;
};

export type ReplaceMediaFormState = {
  status: MediaFormStatus;
  message: string;
  fieldErrors: {
    image?: string;
  };
};

export type DeleteMediaFormState = {
  status: MediaFormStatus;
  message: string;
  fieldErrors: {
    confirmed?: string;
  };
};

export type PrimaryMediaFormState = {
  status: MediaFormStatus;
  message: string;
  fieldErrors: Record<string, never>;
};

export type ReorderMediaFormState = {
  status: MediaFormStatus;
  message: string;
  fieldErrors: {
    imageIds?: string;
  };
};
